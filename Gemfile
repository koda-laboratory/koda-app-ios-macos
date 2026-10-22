source "https://rubygems.org"

gem "fastlane", "~> 2.228.0"

# Plugins are declared once in fastlane/Pluginfile so standalone Fastlane runs
# and the repository-level bundle resolve the same plugins.
plugins_path = File.join(File.dirname(__FILE__), "fastlane", "Pluginfile")
eval_gemfile(plugins_path) if File.exist?(plugins_path)
