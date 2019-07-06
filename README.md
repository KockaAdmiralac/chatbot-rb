# chatbot-rb
A plugin-based bot framework in Ruby for [Fandom's](https://c.fandom.com/) [Special:Chat](https://github.com/Wikia/app/tree/dev/extensions/wikia/Chat2) extension. Originally written by [Kerri Amber](https://github.com/kerriamber) and currently maintained by [KockaAdmiralac](https://github.com/KockaAdmiralac).

## Pull Requests / Issues
If you want to create a PR or open an issue here on GitHub, *that is fine* (and most definitely encouraged!) - however, *please ping me with `@KockaAdmiralac` somewhere in your issue/PR description*. GitHub unfortunately *does not provide a way for me to get notifications of new PRs/issues via e-mail*, unless I am pinged with `@KockaAdmiralac`. Also, while not required, it would be helpful to me if you left your Fandom username so I can contact you further if need be.

## Installation
To run a bot using this framework, Ruby 2.1+ is expected. It was originally developed on the latest stable version and generally will not accommodate any problems that are only affect older versions of Ruby.

## Running
Please follow the format outlined in `main.sample.rb` and `config.sample.yml` to setup a working bot. The Fandom account used to connect to chat does not *need* bot rights, but if you're using a logging plugin or otherwise editing it can be useful.

## Plugins
The plugin system for this bot is **heavily** inspired by that of [Cinch](https://github.com/cinchrb/cinch), albeit very watered down and less useful. See the example plugins for ideas on how to make your own.
