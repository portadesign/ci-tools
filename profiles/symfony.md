- Symfony: wiring of new services and scalar arguments; command exit codes
  and a second run of the same command; subscriber event names.
  `EventSubscriberInterface`, never `#[AsEventListener]` or a
  `kernel.event_listener` tag (exceptions: Doctrine listeners, a
  third-party API that accepts nothing else). A one-off data or schema
  change is a Doctrine migration, not a command; a migration writes no
  console output.
- Style, only on lines the change adds or modifies, all violations as one
  finding with its `path:line` list: `declare(strict_types=1)`, typed
  parameters and returns without `mixed`, no comments (PHPDoc only for
  what the signature cannot carry), no magic constants where config can
  inject the value. `use` imports or fully qualified names is the
  project's choice, never a finding.
