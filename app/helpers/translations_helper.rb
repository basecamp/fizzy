module TranslationsHelper
  TRANSLATIONS = {
    user_name: { "🇺🇸": "Enter your name", "🇪🇸": "Introduce tu nombre", "🇫🇷": "Entrez votre nom", "🇮🇳": "अपना नाम दर्ज करें", "🇩🇪": "Geben Sie Ihren Namen ein", "🇧🇷": "Insira seu nome" },
    email_address:  { "🇺🇸": "Enter your email address", "🇪🇸": "Introduce tu correo electrónico", "🇫🇷": "Entrez votre adresse courriel", "🇮🇳": "अपना ईमेल पता दर्ज करें", "🇩🇪": "Geben Sie Ihre E-Mail-Adresse ein", "🇧🇷": "Insira seu endereço de email" },
    password: { "🇺🇸": "Enter your password", "🇪🇸": "Introduce tu contraseña", "🇫🇷": "Saisissez votre mot de passe", "🇮🇳": "अपना पासवर्ड दर्ज करें", "🇩🇪": "Geben Sie Ihr Passwort ein", "🇧🇷": "Insira sua senha" },
    collection_name: { "🇺🇸": "Give it a name", "🇪🇸": "Dale un nombre", "🇫🇷": "Donnez lui un nom", "🇮🇳": "इसे एक नाम दें", "🇩🇪": "Gib ihm einen Namen", "🇧🇷": "Dê-lhe um nome" }
  }

  def translations_for(translation_key)
    tag.dl(class: "language-list") do
      TRANSLATIONS[translation_key].map do |language, translation|
        concat tag.dt(language)
        concat tag.dd(translation, class: "margin-none")
      end
    end
  end

  def translation_button(translation_key)
    tag.div(class: "position-relative", data: { controller: "popover", action: "keydown.esc->popover#close click@document->popover#closeOnClickOutside", popover_orientation_top_class: "popover-orientation-top" }) do
      tag.button(type: "button", class: "btn", tabindex: -1, data: { action: "popover#toggle" }) do
        concat image_tag("globe.svg", class: "icon", role: "presentation")
        concat tag.span("Translate", class: "for-screen-reader")
      end +
      tag.dialog(class: "lanuage-list-menu popover shadow", data: { popover_target: "menu" }) do
        translations_for(translation_key)
      end
    end
  end
end
