- Pimcore: unbounded Listing/load(), no raw SQL writes on
  `objects`/`object_*`, cache invalidation, reversible migrations,
  DataObject schema BC; one-off changes are migrations, not commands.
- Symfony: wiring of new services and scalar arguments, command exit
  codes, subscriber events and side effects; subscribers, never
  #[AsEventListener].
- PHP: `==`/`in_array()` without strict, `empty()` dropping '0',
  numeric-string array keys.
- Style: strict_types, typed signatures, FQCN without `use`, no comments,
  no magic constants.
