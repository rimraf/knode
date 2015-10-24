#!/usr/bin/env node

'use strict'

const fs           = require('fs')
const pad          = require('pad')
const colors       = require('colors')
const childProcess = require('child_process')
const mode         = require('stat-mode')
const userid       = require('userid')

const statuses = {}
const longest = {}

let gitRoot
let totalBlocks = 0

// find the root git folder (the one with .git)
exec('command git rev-parse --show-toplevel')
  .then((res)      => gitRoot = res.trim())
  .then(()         => exec('command git status --porcelain --ignored --untracked-files=normal ' + gitRoot))
  .then((msg)      => msg.trim().split('\n'))
  .then((porcelainStatuses) => {
    porcelainStatuses.forEach((porcelainStatus) => {
      const status = porcelainStatus.substring(0, 2)
      const filename = porcelainStatus.substring(3)
      statuses[filename] = status
    })
  })
  .then(() => readdir(gitRoot))
  .then((files) => {
    files.unshift('..')
    files.unshift('.')
    return files
  })
  .then((files) => {
    return Promise.all(files.map((filename) => {
      return lstat(filename).then((stats) => {
        totalBlocks += stats.blocks
        return new Stats()
          .mode(mode(stats).toString())
          .nlink(stats.nlink)
          .name(filename)
          .uid(userid.username(stats.uid))
          .gid(userid.groupname(stats.gid))
          .size(stats.size)
          .status(statuses[filename] || '  ')
          .date(new Date(stats.mtime).toDateString())
          .isDirectory(stats.isDirectory())
          .isSymbolicLink(stats.isSymbolicLink())
          .realpath(stats.realpath)
          .stats
      })
    }))
  })
  .then((files) => {
    console.log('total', totalBlocks)
    files.forEach((file) => {
      console.log(
        file.mode,
        pad(longest.nlink,  file.nlink),
        pad(longest.uid,    file.uid)     .grey,
        pad(file.gid,       longest.gid)  .grey,
        pad(longest.size,   file.size),
        pad(longest.date,   file.date),
        pad(longest.status, file.status),
        file.isSymbolicLink
          ? file.name.grey + ' -> ' + file.realpath
          : file.name.blueIf(file.isDirectory)
      )
    })
  })
  .catch((err) => console.log(err))


function Stats() {
  this.stats = {}
  const props = 'mode nlink uid gid size date status name isDirectory isSymbolicLink realpath'.split(' ')
  for (let prop of props) {
    this[prop] = function (value) {
      this.stats[prop] = value
      if (prop === 'isDirectory' || prop == 'isSymbolicLink' || prop === 'name' || prop === 'realpath') return this
      longest[prop] = Math.max(value.toString().length, longest[prop] || 0)
      return this
    }
  }
}

String.prototype.blueIf = function (value) {
  return value ? this.blue : this
}

String.prototype.greenIf = function (value) {
  return value ? this.green : this
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

