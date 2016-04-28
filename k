#!/usr/bin/env node

'use strict'

const fs            = require('fs')
const pad           = require('pad')
const path          = require('path')
const colors        = require('colors')
const dateFormat    = require('dateformat')
const childProcess  = require('child_process')
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

const statusMarkers = require('./lib/status-markers')


const statuses = {}
const longest = {}

/**
 * Gather all the files. We use two commands here because --untracked-files=all
 * used with --ignored in the same command will recursively list all ignored
 * files, which is slow. There is a little duplication because of this, but then
 * use a bit of lodash fun to clean it up.
 */

const statusPromise = Promise.all([
  exec('command git status --porcelain --ignored'),
  exec('command git status --porcelain --untracked-files=all'),
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
.then(removeUntrackedFolders)

// convert the strings into more usable form e.g. {file: 'path', status: '??'}
.then(each(porcelainStatus => {
  const status = porcelainStatus.substring(0, 2);
  const filename = porcelainStatus.substring(3).replace(/\/$/, "");
  statuses[filename] = status;
}))



/**
 * Grab the root dir of the project, run in it's own thread for maximum fastness
 */

const gitRootPromise = exec('command git rev-parse --show-toplevel').then(trim);


/**
 * All
 */
Promise.all([
  gitRootPromise,
  statusPromise
])
.then(results => {
  let totalBlocks = 0
  const gitRoot = results[0];

  readdir(gitRoot)
    .then(concat(['.', '..']))
    .then(files => {
      return Promise.all(files.map(filename => {
        return lstat(filename).then(stats => {
          const fileMode = mode(stats);
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
      }))
    })
    .then(files => {
      console.log('total', totalBlocks)
      files.forEach(file => {
        console.log(
          file.mode,
          pad(longest.nlink,  file.nlink),
          pad(longest.uid,    file.uid)     .grey,
          pad(file.gid,       longest.gid)  .grey,
          pad(longest.size,   file.size),
          pad(longest.date,   file.date),
          statusMarkers[file.status],
          file.isSymbolicLink
            ? file.name.cyan + ' -> ' + path.relative(gitRoot, file.realpath)
            : file.name.blueIf(file.isDirectory).redIf(file.isExecutable)
        )
      })
    })
})
.catch(err)


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
      if ('nlink uid gid size date'.split(' ').indexOf(prop) > -1) {
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

function exec(cmd, options) {
  return new Promise((resolve, reject) => {
    childProcess.exec(cmd, options, (error, stdout, stderr) => {
      if (error) return reject(error)
      resolve(stdout)
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
  }, items);
}
