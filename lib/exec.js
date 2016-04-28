'use strict';

const childProcess = require('child_process')

/**
 * exec
 *
 * Simple promise version of nodes inbuilt exec
 *
 * @param cmd
 * @param options
 * @returns {Promise}
 */
module.exports = function exec(cmd, options) {
  return new Promise((resolve, reject) => {
    childProcess.exec(cmd, options, (error, stdout, stderr) => {
      if (error) return reject(stderr)
      resolve(stdout)
    })
  })
}
