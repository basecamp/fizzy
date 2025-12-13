# Fizzy Customizations

Tài liệu này ghi lại tất cả các tùy chỉnh đã thực hiện cho dự án Fizzy fork.
Sử dụng tài liệu này để theo dõi các thay đổi khi cập nhật từ upstream.

## Tổng quan

Fork này bao gồm:
- **Bản địa hóa tiếng Việt (i18n)** - Dịch toàn bộ giao diện sang tiếng Việt
- **Cấu hình production** - Tùy chỉnh đường dẫn database và URL
- **Branding** - Tùy chỉnh tên sản phẩm và thông tin công ty

---

## 1. Bản địa hóa (i18n)

### Các file đã sửa đổi

#### `config/application.rb`
```ruby
# Thay đổi locale mặc định từ :en sang :vi
config.i18n.default_locale = :vi
config.i18n.available_locales = [:vi, :en]
config.i18n.fallbacks = true
```

#### `config/locales/vi.yml`
File mới chứa toàn bộ bản dịch tiếng Việt cho:
- Layouts & Navigation
- Sessions (Login/Authentication)
- Signups
- Boards
- Cards
- Columns
- Users
- Account settings
- Notifications
- Mailers
- Search
- Shortcuts/Filters
- Events/Activity
- Tags
- Webhooks
- Comments
- Reactions
- Access Tokens
- Error messages
- ActiveRecord validations

#### `config/locales/en.yml`
Bổ sung các key tiếng Anh cho notification helper (fallback):
- `notifications.body.*` - Nội dung thông báo
- `notifications.buttons.*` - Nút bấm
- `notifications.frequency.*` - Tần suất email

#### `app/helpers/notifications_helper.rb`
Chuyển đổi hardcoded strings sang sử dụng `t()` helper:
- `event_notification_body()` - Tất cả các loại thông báo
- `notification_toggle_read_button()` - Nút đánh dấu đã đọc/chưa đọc
- `bundle_email_frequency_options_for()` - Tùy chọn tần suất email
- `card_notification_title()` - Tiêu đề thẻ

#### `app/views/notifications/notification/mention/_body.html.erb`
Thay đổi "@mentioned you" sang sử dụng i18n key.

---

## 2. Cấu hình Production

### `config/database.sqlite.yml`
Thay đổi đường dẫn database từ `storage/` sang `db/`:
```yaml
production:
  primary:
    database: db/production.sqlite3
  cable:
    database: db/production_cable.sqlite3
  cache:
    database: db/production_cache.sqlite3
  queue:
    database: db/production_queue.sqlite3
```

### `config/environments/production.rb`
Thêm cấu hình `APPLICATION_HOST` cho URL generation:
```ruby
# URL options for generating absolute URLs
if application_host = ENV["APPLICATION_HOST"].presence
  config.action_controller.default_url_options = { host: application_host }
  config.action_mailer.default_url_options = { host: application_host }
end
```

**Environment variable cần thiết:**
```bash
APPLICATION_HOST=do.chip.vn  # Thay bằng domain của bạn
```

---

## 3. Branding

### `config/locales/vi.yml`
```yaml
sessions:
  footer:
    product_name: "CHIPVN"
    description: "Hệ thống quản lý công việc nội bộ."
```

---

## Hướng dẫn cập nhật từ Upstream

### Bước 1: Thêm upstream remote (chỉ lần đầu)
```bash
git remote add upstream https://github.com/basecamp/fizzy.git
```

### Bước 2: Fetch và merge
```bash
git fetch upstream
git checkout main
git merge upstream/main
```

### Bước 3: Xử lý conflicts
Các file thường có conflict khi merge:
1. `config/locales/vi.yml` - Thêm translation keys mới
2. `config/locales/en.yml` - Giữ lại notification translations
3. `app/helpers/notifications_helper.rb` - Giữ lại i18n calls
4. `config/application.rb` - Giữ lại locale config
5. `config/environments/production.rb` - Giữ lại APPLICATION_HOST config
6. `config/database.sqlite.yml` - Giữ lại db/ paths

### Bước 4: Kiểm tra translations mới
Sau khi merge, tìm các key mới cần dịch:
```bash
# Tìm các t() calls trong views
grep -r "t(\"" app/views/ --include="*.erb" | grep -v "vi.yml"
```

---

## Commits liên quan

```
05f88ce Add APPLICATION_HOST config for production URL generation
c4ef9e4 Add English translations for notification helper
cbc847e Add Vietnamese translations for notification texts
a9fe326 Change production database path from storage/ to db/
0f719d5 Resolve merge conflicts with origin/main
dce0730 Merge upstream/main and add i18n for new features
a6e736a Continue i18n migration for cards, webhooks, notifications, and filters
```

---

## Checklist khi cập nhật

- [ ] Merge upstream/main
- [ ] Giải quyết conflicts (giữ lại customizations)
- [ ] Kiểm tra các view mới có hardcoded strings
- [ ] Thêm translations mới vào vi.yml
- [ ] Chạy tests: `bin/rails test`
- [ ] Kiểm tra giao diện tiếng Việt
- [ ] Commit và push
