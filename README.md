# AnnotateCallbacks

Automatically annotate Rails model files with a comment block summarizing their ActiveRecord callbacks, including those inherited from concerns and parent classes.

## Example Output

```ruby
# == Callbacks ==
#
#   before_validation  :normalize_email
#   before_save        :encrypt_password
#   before_save        :track_changes                        if: :changed?  [Trackable]
#   after_create       :send_welcome_email
#   after_create       (block: app/models/user.rb:18)
#   after_save         :update_cache                         if: :name_changed?
#   before_destroy     :check_admin
#
# == End Callbacks ==

class User < ApplicationRecord
  include Trackable

  before_validation :normalize_email
  before_save :encrypt_password
  after_create -> { NotificationService.ping(self) }
  # ...
end
```

- Callbacks from concerns are shown with `[ConcernName]`
- Block/lambda callbacks show source location: `(block: path:line)`
- Internal framework callbacks (`autosave_associated_records_for_*`, `dependent: :destroy` etc.) are automatically filtered out

## Installation

Add to your Gemfile:

```ruby
group :development do
  gem "annotate_callbacks"
end
```

```bash
bundle install
```

## Usage

```bash
# Add callback annotations
bundle exec rake callbacks:annotate

# Remove callback annotations
bundle exec rake callbacks:remove
```

## How It Works

Uses `ApplicationRecord.descendants` and Rails runtime reflection (`_save_callbacks`, `_create_callbacks`, etc.) to detect all registered callbacks on each model class.

- Callbacks defined in concerns are included, with source module shown as `[ModuleName]`
- Block/lambda callbacks show relative source location: `(block: app/models/user.rb:10)`
- Symbol conditions (`if: :active?`) are shown; Proc conditions are omitted
- Internal framework callbacks are filtered out by name pattern and source module
- Abstract classes are skipped
- Files are written atomically (Tempfile + mv)
- `rake callbacks:annotate` requires Rails environment; `rake callbacks:remove` does not

## Development

```bash
git clone https://github.com/sloppybook/annotate_callbacks.git
cd annotate_callbacks
bundle install
bundle exec rspec
```

## License

[MIT License](LICENSE.txt)
