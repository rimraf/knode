#!/usr/bin/env node

'use strict'

const meow = require('meow')

const k = require('./lib/k')

const cli = meow(`
    Usage
      $ k [options] [files ...]

    Options
      -a, --all  Include hidden files

`, {
    alias: {
        a: 'all'
    }
});

if (cli.input.length === 0) {
  k(process.cwd())
}

