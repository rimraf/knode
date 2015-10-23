#!/usr/bin/env node

'use strict'

const fs = require('fs')
const childProcess = require('child_process')


// let gitRoot;

// exec('command git rev-parse --show-toplevel')
//   .then((res) => {
//     gitRoot = res.trim();
//     return exec('command git status --porcelain --ignored --untracked-files=normal ' + gitRoot)
//   })
//   .then((msg) => console.log(msg))
//   .catch((err) => console.log(err))

// function exec(cmd, options) {
//   return new Promise((resolve, reject) => {
//     childProcess.exec(cmd, options, (error, stdout, stderr) => {
//       if (error) return reject(error);
//       resolve(stdout);
//     });
//   });
// }


const statRoot = './';

// Stat stuff
fs.readdir(statRoot, (err, files) => {

  for (let statFile of files) {
    fs.stat(statFile, (err, stats) => {
      let file = {
        blocks: stats.blocks,
        name: statFile
      }
      console.log(file);
    })
  }

});
