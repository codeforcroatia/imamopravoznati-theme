ImamoPravoZnati Alaveteli theme
=========================

This is a theme package for Alaveteli.

The intention is to support simple overlaying of templates and
resources without the need to touch the core Alaveteli software.

Typical usage should be limited to:

 * Putting CSS-based customisations in `public/stylesheets/custom.css`

 * Creating your own versions of non-functional pages (like "about
   us", at `lib/views/help/about.rhtml` -- and/or localised versions at
   lib/views/help/about.es.rhtml)

To install::

  ./script/plugin install git://github.com/codeforcroatia/imamopravoznati-theme.git

Look in the lib/ folder of the plugin to see how the overrides happen.

Note that the `install.rb` plugin point sets up a symlink to include
local resource files within the Rails `public/` directory.

Based on [tuderechoasaber-theme](https://github.com/civio/tuderechoasaber-theme) for Alaveteli v0.12 - Copyright (c) 2011 David Cabo
Based on [dirittodisapere-theme](https://github.com/mysociety/dirittodisapere-theme) for Alaveteli v0.20 - Copyright (c) 2011 mySociety, released under the MIT license
