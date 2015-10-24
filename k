#!/usr/bin/env node

'use strict'

const fs           = require('fs')
const pad          = require('pad')
const childProcess = require('child_process')
const mode         = require('stat-mode');
const userid       = require('userid');

const statuses = {};
const longest = {};
let gitRoot;

// find the root git folder (the one with .git)
exec('command git rev-parse --show-toplevel')
  .then((res)      => gitRoot = res.trim())
  .then(()         => exec('command git status --porcelain --ignored --untracked-files=normal ' + gitRoot))
  .then((msg)      => msg.trim().split('\n'))
  .then((porcelainStatuses) => {
    porcelainStatuses.forEach((porcelainStatus) => {
      const status = porcelainStatus.substring(0, 2);
      const filename = porcelainStatus.substring(3);
      statuses[filename] = status;
    })
  })
  .then(() => readdir(gitRoot))
  .then((files) => {
    files.unshift('..');
    files.unshift('.');
    return files;
  })
  .then((files) => {
    return Promise.all(files.map((filename) => {
      return stat(filename).then((stats) => {
        return new Stats()
          .mode(mode(stats).toString())
          .nlink(stats.nlink)
          .name(filename)
          .uid(userid.username(stats.uid))
          .gid(userid.groupname(stats.gid))
          .size(stats.size)
          .status(statuses[filename] || '  ')
          .date(new Date(stats.mtime).toDateString())
          .stats;
      })
    }))
  })
  .then((files) => {
    files.forEach((file) => {
      console.log(
        file.mode,
        pad(longest.nlink,  file.nlink),
        pad(longest.uid,    file.uid),
        pad(file.gid,       longest.gid),
        pad(longest.size,   file.size),
        pad(longest.date,   file.date),
        pad(longest.status, file.status),
        file.name
      );
    })
  })
  .catch((err) => console.log(err))

function Stats() {
  this.stats = {};
  const props = 'mode nlink uid gid size date status name'.split(' ')
  for (let prop of props) {
    this[prop] = function (value) {
      this.stats[prop] = value;
      longest[prop] = Math.max(value.toString().length, longest[prop] || 0);
      return this;
    }
  }
}

function readdir(path) {
  return new Promise((resolve, reject) => {
    fs.readdir(path, (err, files) => {
      if (err) return reject(err);
      resolve(files);
    });
  });
}

function stat(path) {
  return new Promise((resolve, reject) => {
    fs.stat(path, (err, stats) => {
      if (err) return reject(err);
      resolve(stats);
    });
  });
}

function exec(cmd, options) {
  return new Promise((resolve, reject) => {
    childProcess.exec(cmd, options, (error, stdout, stderr) => {
      if (error) return reject(error);
      resolve(stdout);
    });
  });
}

