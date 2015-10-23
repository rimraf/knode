#!/usr/bin/env node

'use strict'

const fs = require('fs')
const childProcess = require('child_process')

const Mode = require('stat-mode');


let gitRoot;

exec('command git rev-parse --show-toplevel')
  .then((res) => {
    gitRoot = res.trim();
    return exec('command git status --porcelain --ignored --untracked-files=normal ' + gitRoot)
  })
  .then((msg) => console.log(msg))
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
