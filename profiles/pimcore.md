- Pimcore persistence: DataObjects, assets and documents change through
  the Pimcore API, in migrations too. A raw SQL write on `objects` or
  `object_*` skips versions, cache, events and dependency tracking: ❌.
  Static tables (`settings_store`, translations, the project's own) may
  take SQL. `save()` carries a version note. `setOmitMandatoryCheck(true)`
  only in an import.
- Listings: no unbounded `load()` on a class that grows; chunk it. Pimcore
  `key` and asset `filename` are case-sensitive: `Foo` and `foo` can both
  exist, a case-insensitive PHP match finds both.
- Class definitions: `ClassDefinition::save()` drops every column and
  relation missing from `getFieldDefinitions()`, for all objects, outside
  any transaction. A call to `setFieldDefinitions()` is ❌; so is code or a
  migration that removes or retypes a field with no step that moves its
  data out first. Schema BC: a removed or renamed field still read by
  code, a Data Hub config or an importer.
- Migrations: `down()` reverses `up()`, or the description says why it
  cannot.
- Importers and bulk commands: chunked, `\Pimcore::collectGarbage()` per
  batch, idempotent through a stable external key, a decision per external
  I/O error (skip, retry or abort), proper exit codes.
- Data Hub: configs are YAML under `var/config/data_hub/`, never only in
  `settings_store`; no API keys or credentials in them. GraphQL resolvers
  check workspace permissions.
- Events: Pimcore events (`DataObjectEvents`, `AssetEvents`) over
  overriding core classes.
