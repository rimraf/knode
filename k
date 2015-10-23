#!/usr/bin/env node

'use strict'

const fs = require('fs')
const childProcess = require('child_process')

const Mode = require('stat-mode');

const filesWithState = [];

let gitRoot;

exec('command git rev-parse --show-toplevel')
  .then((res) => {
    gitRoot = res.trim();
    return exec('command git status --porcelain --ignored --untracked-files=normal ' + gitRoot)
  })
  .then((msg) => {
    const statuses = msg.trim().split('\n');
    statuses.forEach((porcelainStatus) => {
      const status = porcelainStatus.substring(0, 2);
      const filename = porcelainStatus.substring(3);
      filesWithState.push({filename, status});
    })
  })
  .then(() => console.log(filesWithState))
  .catch((err) => console.log(err))

function exec(cmd, options) {
  return new Promise((resolve, reject) => {
    childProcess.exec(cmd, options, (error, stdout, stderr) => {
      if (error) return reject(error);
      resolve(stdout);
    });
  });
}


const statRoot = './';
let dirContent = [];

// Stat stuff
fs.readdir(statRoot, (err, files) => {

  for (let statFile of files) {
    fs.stat(statFile, (err, stats) => {

      let mode = new Mode(stats)

      let file = {
        mode: mode.toString(),
        blocks: stats.blocks,
        name: statFile,
        uid: stats.uid,
        gid: stats.gid,
        size: stats.size,
        mtime: stats.mtime,
      }
      console.log(file);
    })
  }

});
