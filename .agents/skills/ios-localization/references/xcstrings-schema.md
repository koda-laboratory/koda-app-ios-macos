# `.xcstrings` Schema Used by Koda

Apply this reference to:

- `Koda/Resources/Localizable.xcstrings`.
- `Koda/Resources/InfoPlist.xcstrings`.

## Basic structure

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "Retry" : {
      "comment" : "Button shown after a failed request",
      "localizations" : {
        "es" : {
          "stringUnit" : {
            "state" : "needs_review",
            "value" : "Reintentar"
          }
        }
      }
    }
  },
  "version" : "1.0"
}
```

## States

| State | Use |
|---|---|
| `new` | Xcode detected new or changed source content |
| `needs_review` | A translation exists but requires human review |
| `translated` | A human reviewed and approved the translation |

Always mark agent-generated translations as `needs_review`. Never change a human `translated` entry unless explicitly requested or the source changed.

## Placeholders

- Preserve count and type: `%@`, `%lld`, `%d`, and others.
- Use positions such as `%1$@` and `%2$@` when a language needs different argument order.
- Review every string with placeholders manually; valid JSON can still fail at runtime.

## Plurals

Use `variations.plural` only when a string depends on a count. Include the CLDR categories required by each language instead of assuming only `one` and `other`.

```json
"%lld game" : {
  "comment" : "Number of games",
  "localizations" : {
    "en" : {
      "variations" : {
        "plural" : {
          "one" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%lld game"
            }
          },
          "other" : {
            "stringUnit" : {
              "state" : "translated",
              "value" : "%lld games"
            }
          }
        }
      }
    }
  }
}
```

## Editing hygiene

- Preserve valid UTF-8 JSON.
- Avoid reformatting the entire catalog for a small change.
- Preserve comments, states, and existing RTL marks.
- Remove template keys only after confirming they are unused.

## Validation

```bash
xcrun xcstringstool print Koda/Resources/Localizable.xcstrings
xcrun xcstringstool print Koda/Resources/InfoPlist.xcstrings
```

Then build both platforms and test at least one non-English language for placeholder, truncation, and fallback issues.
