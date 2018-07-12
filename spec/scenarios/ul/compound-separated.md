* Make a new project folder

  ```js
  const fs = require('fs')
  fs.mkdirSync('project')
  ```

* Initialize a new repository

  ```js
  const git = require('isomorphic-git')
  const repo = { fs, dir: 'project' }
  await git.init(repo)
  ```

  This is equivalent to the following command:

      $ git init project

* Create boilerplate files

  | Filename    | Purpose                     |
  | ----------- | --------------------------- |
  | README.adoc | Introduces the project      |
  | .gitignore  | Ignores non-versioned files |

* Create source files

  We can't help you here.
  This part you'll have to do on your own.

  > Best of luck!
