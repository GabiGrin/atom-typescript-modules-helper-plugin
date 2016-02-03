# typescript-modules-helper

Adds "import Foo from '../bar'" statements for you.  
Adds "go to declaration" that works with modules declared elsewhere, and fallbacks to atom-typescript go to declaration, just ctrl/cmd click an indexed symbol.
# Usage
1. Go to your project
2. Open command pallette -> type "Build index" -> press enter. This won't be needed soon.
3. With the caret on the symbol you wish to import, press ctrl+alt+m (or command "Typescript Import - Insert" in command line)
4. Profit!

# Notes
- This will only work with Typescript projects that use ES6 Modules syntax
- It only works with default exports at the moment
- Currently you have to re-build the index (see Usage step #2) each time you add/change things. This will be fixed very soon!
- The code is horrible, this started as small test but Atom proved to be so easy to customize I just went on hacking with a mix of JS and CS. Please wear sunglasses while looking at the code.
- Because of the above, this is not tested at all.

#Todo
- Add example gif
- Remove need for building index
- Make non-default imports/exports work as well
- Use [code-links](https://atom.io/packages/code-links) for the go-to-declaration
- Make it work with regular CommonJS modules
- Rewrite using Typescript

#Contributing
dokkis:
- workspace.scan now is limited to ts and js files
- added support for multiple export symbol in one file 
- support for non default export
- support for interface, namespace and enum
- added warning notification if you try to import multiple times the same symbol
- added error notification if the plugin does not find the symbol
- added support for numbers in the symbol definition (example ClassName1)
