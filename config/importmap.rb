# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin "@hotwired/hotwire-native-bridge", to: "@hotwired--hotwire-native-bridge.js"
pin "@rails/request.js", to: "@rails--request.js" # @0.0.13

pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/helpers", under: "helpers"
pin_all_from "app/javascript/initializers", under: "initializers"
pin_all_from "app/javascript/bridge/initializers", under: "bridge/initializers"
pin_all_from "app/javascript/bridge/helpers", under: "bridge/helpers"
pin_all_from "app/javascript/bridge/controllers/bridge", under: "controllers/bridge", to: "bridge/controllers/bridge"
pin "lexxy"
pin "@rails/activestorage", to: "activestorage.esm.js"
pin "@rails/actiontext", to: "actiontext.esm.js"
