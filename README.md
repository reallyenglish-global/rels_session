# RelsSession

Gem to access and write to Rallyenglish Session data

## Usage

```ruby
# config/initilizers/session_store.rb
Rails.application.config.session_store(
  RelsSession::SessionStore
)
```

Session store config schema can be used to validate Settings.

```ruby
# config/initilizers/config.rb
Config.setup do |config|
  config.schema do
    required(:session_store).hash(RelsSession::SessionStoreConfigSchema)
    ...
  end
end
```
