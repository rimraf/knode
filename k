#!/usr/bin/env node

const fs = require('fs')
const childProcess = require('child_process')

exec('git status').then((msg) => console.log(msg)).catch((err) => console.log(err))

function exec(cmd, options) {
  return new Promise((resolve, reject) => {
    childProcess.exec(cmd, options, (error, stdout, stderr) => {
      if (error) return reject(error);
      resolve(stdout);
    });
  });
}
