# RelsSession

Gem to access and write to Rallyenglish Session data

## Usage


```ruby
require 'rels_session'

Rails.application.config.session_store(
  RelsSession::SessionStore,
  secure: !Rails.env.test?
)
```
