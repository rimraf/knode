#!/usr/bin/env node

'use strict'

const fs = require('fs')
const childProcess = require('child_process')

const gitStatus = {};
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
      const file = porcelainStatus.substring(2);
      if (!gitStatus[status]) gitStatus[status] = [];
      gitStatus[status].push(file);
    })
  })
  .then(() => console.log(gitStatus))
  .catch((err) => console.log(err))








function exec(cmd, options) {
  return new Promise((resolve, reject) => {
    childProcess.exec(cmd, options, (error, stdout, stderr) => {
      if (error) return reject(error);
      resolve(stdout);
    });
  });
}
