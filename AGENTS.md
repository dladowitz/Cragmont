# Cragmont Instructions
- Use "participant" for people signed up for trips; reserve "signup" for the registration record or action.


## Coding and Infrastructure Conventions
- Prefer HAML for Rails views.
- Use `gh` for GitHub PR creation and merging. Do not use the GitHub connector unless explicitly asked.
- When I say "Push to github" this means to commit the code. Push the branch to Github. Create a PR. Add a meaningful description of the changes. Watch for tests to pass. Then merge the PR. Lastly checkout main locally and then pull origin main.


## Validation
- Run `rbenv exec ruby bin/rails test` before pushing code.
- For focused changes, run the relevant targeted tests first, then the full suite before pushing.
