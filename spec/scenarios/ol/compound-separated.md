1. Make a new project folder

   ```js
   const fs = require('fs')
   fs.mkdirSync('project')
   ```

1. Initialize a new repository

   ```js
   const git = require('isomorphic-git')
   const repo = { fs, dir: 'project' }
   await git.init(repo)
   ```

   This is equivalent to the following command:

       $ git init project

1. Create source files

   We can't help you here.
   This part you'll have to do on your own.

   > Best of luck!
