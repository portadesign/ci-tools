- Symfony: wiring of new services and scalar arguments; command exit codes
  and a second run of the same command; subscriber event names, priorities
  and hidden side effects; blast radius across shared services.
  `EventSubscriberInterface`, never `#[AsEventListener]` or a
  `kernel.event_listener` tag (exceptions: Doctrine listeners, a
  third-party API that accepts nothing else). A one-off data or schema
  change is a Doctrine migration, not a command; a migration writes no
  console output.
- Style, only on lines the change adds or modifies, all violations as one
  finding with its `path:line` list: `declare(strict_types=1)`, typed
  parameters and returns without `mixed`, no comments (PHPDoc only for
  what the signature cannot carry), no magic constants where config can
  inject the value.
- PHP input traps: walk every new or changed condition on outside input
  (file and folder names, request parameters, CSV/API fields) through this
  list and name the value you tried. A value that breaks the code is ❌; a
  trap the code merely resembles is no finding.
  - Numeric-string keys become int: `$a['123']` is stored under `123`.
    `array_keys()`, `array_flip()`, `array_combine()` and
    `array_fill_keys()` then yield int, which throws a `TypeError` in a
    `string` parameter under `strict_types` and fails `===` against
    `'123'`; `array_merge()` renumbers those keys. The values are
    untouched: `array_values()` of string values stays `string[]`.
  - Loose comparison and casts: `==`; `in_array()`, `array_search()`,
    `array_keys($a, $v)` without `strict: true`. `'1e1' == '10'` is true;
    `(int) 'abc'` is `0`.
  - Falsy strings: `empty('0')` and `if ($name)` drop the value `'0'`.
  - Request parameter as array: `?id[]=1` hands an array to code expecting
    a string.
  - Name says nothing about type: a folder can be called `archive.html`,
    a file can lack an extension or be `a.tar.gz`.
  - Case and Unicode: `str_ends_with('A.HTML', '.html')` is false;
    `strtolower()` changes only ASCII.
  - Empty, duplicate, whitespace: empty list, one item, two items equal
    after normalisation, leading or trailing spaces.
- Tests: read the assertions; a test file is not evidence of coverage. For
  each new or changed test name the change to production code that turns
  it red. ❌: no such change exists; the test asserts the value a stub was
  told to return; the same expression computes both sides; its only
  assertion is `assertNotNull`, `assertIsArray` or `assertInstanceOf` on
  the declared type; a new or changed condition on outside input has no
  test that goes red when the condition is deleted or flipped. ⚠️: a
  missing boundary or failure mode, `expects($this->once())` on a
  collaborator the requirement never mentions, a test that kills no
  mutation another test does not already kill.
