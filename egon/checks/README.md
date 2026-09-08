# Checks

One file per feature slug: `{slug}.json`, written by the planner and executed by the
scenario suite with no agent in the loop.

```json
[
  {
    "name": "victory screen shows the final score",
    "scenario": "endgame_victory",
    "steps": [
      { "await": "window.__egon.state().screen", "equals": "victory" },
      { "press": "Space" },
      { "expect": "window.__egon.state().score", "equals": 4200 },
      { "screenshot": "victory-score" }
    ]
  }
]
```

A step is exactly one of `press`, `click` / `move` (`[x, y]` in a 960×540 viewport),
`drag`, `await`, `expect`, or `screenshot`. `await` and `expect` take one comparator:
`equals`, `at_least`, `at_most`, `changed_by`, or `contains`.

Waiting is always a condition. There is no sleep step.

Every check on this branch runs on every test cycle, so these files are the regression
suite. They live here rather than in the bot's data directory because they name bridge
fields and viewport coordinates: a revert should take its checks with it.
