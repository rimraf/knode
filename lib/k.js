'use strict';

const fs            = require('fs')
const pad           = require('pad')
const path          = require('path')
const colors        = require('colors')
const dateFormat    = require('dateformat')
const mode          = require('stat-mode')
const userid        = require('userid')
const flatten       = require('lodash/fp/flatten')
const split         = require('lodash/fp/split')
const trim          = require('lodash/fp/trim')
const trimEnd       = require('lodash/fp/trimEnd')
const trimStart     = require('lodash/fp/trimStart')
const map           = require('lodash/fp/map')
const uniq          = require('lodash/fp/uniq')
const dropRight     = require('lodash/fp/dropRight')
const reject        = require('lodash/fp/reject')
const concat        = require('lodash/fp/concat')
const each          = require('lodash/fp/each')
const join          = require('lodash/fp/join')
const has           = require('lodash/fp/has')
const mapKeys       = require('lodash/fp/mapKeys')
const reduce        = require('lodash/fp/reduce')
const assign        = require('lodash/fp/assign')

const exec          = require('./exec')
const statusMarkers = require('./status-markers')

const longest = {}

module.exports = function k(dir) {

  exec('command git rev-parse --show-toplevel')
    .then(trim)
    .then(gitRoot => kGitDir(dir, gitRoot))
    .catch(() => kDir(dir))

}

function kGitDir(dir, gitRoot) {
  var totalBlocks = 0
  getStatus(dir, gitRoot)
    .then(statuses => {
      const statPromises = [];

      for (let filename in statuses) {
        if (statuses[filename] === 'D ' || statuses[filename] === ' D') {
          statPromises.push(Promise.resolve(
            new Stats()
              .mode('··········')
              .nlink('···')
              .uid('·············')
              .gid('·····')
              .size('·····')
              .status(statuses[filename] || '  ')
              .date('··· ·· ·····')
              .name(filename)
              .isDirectory('')
              .isSymbolicLink('')
              .realpath('')
              .isExecutable('')
              .stats
          ))
          continue
        }
        const statPromise = lstat(dir + '/' + filename).then(stats => {

          const fileMode = mode(stats)
          totalBlocks += stats.blocks

          return new Stats()
            .mode(fileMode.toString())
            .nlink(stats.nlink)
            .uid(userid.username(stats.uid))
            .gid(userid.groupname(stats.gid))
            .size(stats.size)
            .status(statuses[filename] || '  ')
            .date(dateFormat(new Date(stats.mtime), 'mmm dd HH:MM'))
            .name(filename)
            .isDirectory(stats.isDirectory())
            .isSymbolicLink(stats.isSymbolicLink())
            .realpath(stats.realpath)
            .isExecutable(isExecutable(fileMode))
            .stats
        })

        statPromises.push(statPromise)

      }
      return Promise.all(statPromises)
    })
      .then(files => {

        console.log('total', totalBlocks)

        files.forEach(file => {

          const isDeleted = file.status === 'D ' || file.status === ' D'

          const results = [
            pad(longest.mode,   file.mode).greyIf(isDeleted),
            pad(longest.nlink,  file.nlink).greyIf(isDeleted),
            pad(longest.uid,    file.uid)     .grey.greyIf(isDeleted),
            pad(file.gid,       longest.gid)  .grey.greyIf(isDeleted),
            pad(longest.size,   file.size).greyIf(isDeleted),
            pad(longest.date,   file.date).greyIf(isDeleted)
          ]

           results.push(statusMarkers[file.status])

          const filename = file.isSymbolicLink
            ? file.name.cyan + ' -> ' + path.relative(gitRoot, file.realpath)
            : file.name.blueIf(file.isDirectory).redIf(file.isExecutable).greyIf(isDeleted)

          results.push(filename)

          console.log.apply(console, results)
        })
      })
}

function kDir() {
  
}

// const statuses = {}
// const longest = {}
// let isGit = true
// let root
// let totalBlocks = 0






// /**
//  * Find the root of the git repo we are in, if we are not inside a repo, just
//  * set the root to the cwd.
//  */


// module.exports = function () {
//   exec('command git rev-parse --show-toplevel')
//     .then(trim)
//     .then(gitRoot => root = gitRoot)
//     .catch(() => {
//       isGit = false
//       root = process.cwd()
//     })
//     .then(() => {
//       if (isGit) return getStatus()
//     })
//     .then(() => {
//       readdir(root)
//         .then(files => {

//           return Promise.all(files.map(filename => {

//             return lstat(filename).then(stats => {

//               const fileMode = mode(stats)
//               totalBlocks += stats.blocks

//               return new Stats()
//                 .mode(fileMode.toString())
//                 .nlink(stats.nlink)
//                 .uid(userid.username(stats.uid))
//                 .gid(userid.groupname(stats.gid))
//                 .size(stats.size)
//                 .status(statuses[filename] || '  ')
//                 .date(dateFormat(new Date(stats.mtime), 'mmm dd HH:MM'))
//                 .name(filename)
//                 .isDirectory(stats.isDirectory())
//                 .isSymbolicLink(stats.isSymbolicLink())
//                 .realpath(stats.realpath)
//                 .isExecutable(isExecutable(fileMode))
//                 .stats

//             })
//           }))
//       })
      // .then(files => {

      //   console.log('total', totalBlocks)

      //   files.forEach(file => {

      //     const results = [
      //       file.mode,
      //       pad(longest.nlink,  file.nlink),
      //       pad(longest.uid,    file.uid)     .grey,
      //       pad(file.gid,       longest.gid)  .grey,
      //       pad(longest.size,   file.size),
      //       pad(longest.date,   file.date)
      //     ]

      //     if (isGit) {
      //      results.push(statusMarkers[file.status])
      //     }

      //     const filename = file.isSymbolicLink
      //       ? file.name.cyan + ' -> ' + path.relative(gitRoot, file.realpath)
      //       : file.name.blueIf(file.isDirectory).redIf(file.isExecutable)

      //     results.push(filename)

      //     console.log.apply(console, results)
      //   })
      // })
  // })
//   .catch(err)
// }




function getStatus(dir, gitRoot) {

  /**
   * We use two commands here because --untracked-files=all
   * used with --ignored in the same command will recursively list all ignored
   * files, which is slow. There is a little duplication because of this, but then
   * use a bit of lodash fun to clean it up.
   */
  return Promise.all([
    exec(`command git status ${dir} --porcelain --ignored`),
    exec(`command git status ${dir} --porcelain --untracked-files=all`)
  ])

  // split each string into an array of files
  .then(map(split('\n')))

  // remove the last element in each array as it is always an empty string
  .then(map(dropRight(1)))

  // squish them together and remove duplicates
  .then(flatten)
  .then(uniq)

  // untracked folders need to be removed because untracked files are also there
  // and untracked folders are just extra noise
  // .then(removeUntrackedFolders)

  // convert the strings into more usable form e.g. {file: 'path', status: '??'}
  .then(reduce((result, porcelainStatus) => {

    const status = porcelainStatus.substring(0, 2)
    const filename = porcelainStatus.substring(3).replace(/\/$/, "")

    const relativeFilename = `${gitRoot}/${filename}`.replace(`${dir}/`, '')

    result[relativeFilename] = status
    return result

  }, {}))

  .then(statuses => {
    return readdir(dir)
      .then(dir => {
        trimStatues(dir, statuses)
        return dir
      })
      .then(reject(file => statuses[file]))
      // .then(reject(file => fs.lstatSync(file).isDirectory())) // remove sync
      .then(reduce((result, file) => {
        result[file] = '  '
        return result
      }, {}))
      .then(assign(statuses))
      .then(o => Object.keys(o).sort().reduce((r, k) => (r[k] = o[k], r), {}))
  })

}

function trimStatues(dir, statuses) {
  for (var file in statuses) {
    if (statuses[file] !== '!!') continue
    dir.forEach(i => {
      if (file === i) return
    })
    delete statuses[file]
  }
}






function log(data) {
  console.log(data)
  return data
}

function err(data) {
  console.error(data)
  return data
}

function Stats() {
  this.stats = {}
  const props = 'mode nlink uid gid size date status name isDirectory isSymbolicLink isExecutable realpath'.split(' ')
  for (let prop of props) {
    this[prop] = function (value) {
      this.stats[prop] = value
      // if ('one of these')
      if ('mode nlink uid gid size date'.split(' ').indexOf(prop) > -1) {
        longest[prop] = Math.max(value.toString().length, longest[prop] || 0)
      }
      return this
    }
  }
}

String.prototype.blueIf = function (value) {
  return value ? this.blue : this
}

String.prototype.redIf = function (value) {
  return value ? this.red : this
}

String.prototype.greenIf = function (value) {
  return value ? this.green : this
}

String.prototype.greyIf = function (value) {
  return value ? this.grey : this
}


function isExecutable(mode) {
  return mode.owner.execute || mode.group.execute || mode.others.execute
}

function readdir(path) {
  return new Promise((resolve, reject) => {
    fs.readdir(path, (err, files) => {
      if (err) return reject(err)
      resolve(files)
    })
  })
}

function lstat(path) {
  return new Promise((resolve, reject) => {
    fs.lstat(path, (err, stats) => {
      if (err) return reject(err)
      if (stats.isSymbolicLink()) return attachRealPath(stats, path).then(resolve, reject)
      resolve(stats)
    })
  })
}

function attachRealPath(stats, path) {
  return realpath(path).then((resolvedPath) => {
    stats.realpath = resolvedPath
    return stats
  })
}

function realpath(path) {
  return new Promise((resolve, reject) => {
    fs.realpath(path, (err, resolvedPath) => {
      if (err) return reject(err)
      resolve(resolvedPath)
    })
  })
}


/**
 * Removes any strings from an array that start '??' and end '/'
 * i.e. untracked folders
 */
function removeUntrackedFolders(items) {
  return reject(item => {
    return item.substr(0, 2) === '??' && item.substr(-1) === '/'
  }, items)
}
