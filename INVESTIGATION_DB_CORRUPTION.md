# Investigation: Database Corruption

## Problème identifié

La corruption de la base de données SQLite semble être causée par une **double exécution** des opérations de création de mentions et de card_links.

## Séquence problématique

1. **Commit 4fa226c47** : "Create mentions and card_links synchronously in API"
   - Ajoute des appels synchrones à `create_mentions` et `create_card_links` dans `Api::CommentsController#create`

2. **Problème** : Quand un commentaire est créé via l'API :
   - Le commentaire est créé avec `create!`
   - Les callbacks `after_save_commit` sont déclenchés :
     - `create_mentions_later` → lance `Mention::CreateJob` en arrière-plan
     - `create_card_links_later` → lance `CardLink::CreateJob` en arrière-plan
   - Ensuite, on appelle manuellement `create_mentions` et `create_card_links` de manière synchrone
   - Les jobs en arrière-plan s'exécutent aussi et essaient de créer les mêmes mentions/card_links

3. **Résultat** : Double création avec des transactions concurrentes qui peuvent corrompre SQLite, surtout avec le mode WAL.

## Fichiers concernés

- `app/controllers/api/comments_controller.rb` (lignes 18-21)
- `app/models/concerns/mentions.rb` (ligne 7: `after_save_commit :create_mentions_later`)
- `app/models/concerns/card_links.rb` (ligne 7: `after_save_commit :create_card_links_later`)

## Solution appliquée

**Fichier modifié** : `app/controllers/api/comments_controller.rb`

Désactiver les callbacks `after_save_commit` **avant** la création du commentaire pour éviter la double exécution :

```ruby
# Disable callbacks before creation to prevent double execution
Comment.skip_callback(:commit, :after, :create_mentions_later, raise: false)
Comment.skip_callback(:commit, :after, :create_card_links_later, raise: false)

begin
  comment = @card.comments.create!(...)
  comment.create_mentions(mentioner: Current.user)
  comment.create_card_links(creator: Current.user)
ensure
  # Re-enable callbacks for future operations
  Comment.set_callback(:commit, :after, :create_mentions_later)
  Comment.set_callback(:commit, :after, :create_card_links_later)
end
```

Cela évite :
- La double création de mentions/card_links
- Les transactions concurrentes qui peuvent corrompre SQLite
- Les problèmes avec le mode WAL de SQLite

## Autres changements liés

1. **Fix du journal mode SQLite** : `config/initializers/sqlite_journal_mode.rb` (SUPPRIMÉ)
   - Était une solution de contournement pour les erreurs d'I/O avec WAL
   - **Supprimé** car la cause racine (double exécution) est corrigée
   - Rails 7.1+ utilise WAL par défaut, ce qui devrait fonctionner correctement maintenant

2. **Amélioration de la gestion des erreurs** : `app/controllers/api/base_controller.rb`
   - Ajout de `rescue_from StandardError` pour capturer toutes les exceptions
   - Retourne toujours du JSON au lieu de HTML/JavaScript

