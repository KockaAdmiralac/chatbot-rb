chatbot-rb
==========

A plugin-based bot framework in Ruby for [Wikia's](http://wikia.com/) [Special:Chat](https://github.com/Wikia/app/tree/dev/extensions/wikia/Chat2) extension. Originally written by [sactage](https://github.com/sactage), currently maintained by [KockaAdmiralac](https://github.com/KockaAdmiralac)

Pull Requests / Issues
======================
If you want to create a PR or open an issue here on GitHub, *that is fine* (and most definitely encouraged!) - however, *please ping me with `@KockaAdmiralac` somewhere in your issue/PR description*. GitHub unfortunately *does not provide a way for me to get notifications of new PRs/issues via e-mail*, unless I am pinged with `@KockaAdmiralac`. Also, while not required, it would be helpful to me if you left your Wikia username so I can contact you further if need be.

Installation
============
To run a bot using this framework, Ruby 2.1+ is expected. I develop on the latest stable version (2.1.3 at the time of writing), and generally will not accommodate any problems that are only affect older versions of Ruby.

*Note*: The framework does not currently work on Windows with Ruby 2.1.3 due to an issue with `mediawiki-gateway` and the `ffi` gem.

This framework requires [HTTParty](https://rubygems.org/gems/httparty) and [mediawiki-gateway](https://rubygems.org/gems/mediawiki-gateway). You can install them both with `[sudo] gem install httparty mediawiki-gateway`.

Running
=======
Please follow the format outlined in `main.sample.rb` and `config.sample.yml` to setup a working bot. The Wikia account used to connect to chat will not *need* bot rights, but if you're using a logging plugin or otherwise editing it will be useful.

Plugins
=======
The plugin system for this bot is **heavily** inspired by that of [Cinch](https://github.com/cinchrb/cinch), albeit very watered down and less useful. See the example plugins for ideas on how to make your own.
