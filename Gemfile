source "https://rubygems.org"

gem "fastlane", "~> 2.220"

# representable (pulled in transitively by fastlane's google-apis-core) does a
# bare `require "multi_json"` at load time but no longer declares it as a hard
# runtime dependency, so it must be requested explicitly or fastlane crashes on
# boot ("multi_json is not part of the bundle").
gem "multi_json"

# Fastlane plugins (e.g. firebase_app_distribution). Loading the Pluginfile here
# records the plugin gems in Gemfile.lock so CI's bundler-cache restores them.
plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
