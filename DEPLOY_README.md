# Helpful things to remember when deploying to RubyGems

Ensure the version number is updated (lib/fakes3/version.rb)

Ensure the tests pass
```
  rake test_server followed by rake test
```

Build the Gem
```
  gem build fakes3.gemspec
```

Push to RubyGems
```
  gem push fakes3-VERSION.gem
```
