# vim-ms-translator

[![TravisCI](https://travis-ci.org/KazuakiM/vim-ms-translator.svg?branch=master)](https://travis-ci.org/KazuakiM/vim-ms-translator)
[![AppVeyor](https://ci.appveyor.com/api/projects/status/lte1vdem9lmsyjo3/branch/master?svg=true)](https://ci.appveyor.com/project/KazuakiM/vim-ms-translator/branch/master)
[![Issues](https://img.shields.io/github/issues/KazuakiM/vim-ms-translator.svg)](https://github.com/KazuakiM/vim-ms-translator/issues)
[![Document](https://img.shields.io/badge/doc-%3Ah%20mstranslator.txt-blue.svg)](doc/mstranslator.txt)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This plugin is Microsoft Translator API Client.  
Microsoft Translator API is "https://www.microsoft.com/en-us/translator/".

![usage](https://kazuakim.github.io/img/vim-ms-translator.gif)

## Usage

1. You can get subscription_key for Microsoft Translator API.
1. You set to vimrc or something. I think you should not public this setting
   ```vim
   let g:mstranslator#Config = {
   \     'subscription_key': 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
   \ }
   ```

## Author

[KazuakiM](https://github.com/KazuakiM/)

## License

This software is released under the MIT License, see LICENSE.
