'use strict'

module.exports = {
  // https://git-scm.com/docs/git-status
  // default
  '  ': '|'.green,

  // not updated
  ' M': '+'.red,
  ' D': '-'.red, //(doesn't work because deleted files are not shown by readdir)

  // updated in index
  'M ': '+'.green,
  'MM': '+'.green,
  'MD': '+'.green,

  // added to index
  'A ': '+'.green,
  'AM': '+'.green,
  'AD': '+'.green,

  // deleted from index (don't work because deleted files are not shown by readdir)
  'D ': '-'.green,
  'DM': '-'.green,

  // renamed in index (don't work because output from git status --porcelain is 'oldfile -> newfile' look at git status -z)
  'R ': '>'.green,
  'RM': '>'.green,
  'RD': '>'.green,

  // copied in index (?)
  'C ': '>'.green,
  'CM': '>'.green,
  'CD': '>'.green,

  // untracked
  '??': '+'.yellow,

  // ignored
  '!!': '|'.white,
}
