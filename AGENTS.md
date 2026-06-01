# Cragmont Instructions
- Use "participant" for people signed up for trips; reserve "signup" for the registration record or action.
- Use fun rock climbing terminology for the site. For example when someone successfully does something say something like "On belay! You've successfully signed up". When they get an error you might say "Wow that was a whipper. You've exceeded the signup limit. 
In general make the verbage fun and engaging for rock climbers. 



## Coding and Infrastructure Conventions
- Prefer HAML for Rails views.
- Use `gh` for GitHub PR creation and merging. Do not use the GitHub connector unless explicitly asked.
- When I say "Push to github" this means to commit the code. Push the branch to Github. Create a PR. Add a meaningful description of the changes. Watch for tests to pass. Then merge the PR. Lastly checkout main locally and then pull origin main.
- You are authorized to use `gh` for interactions with Github. Don't block yourself to ask for authorization.
- Any time an input field is required mark it with a red *

## Validation
- Run `rbenv exec ruby bin/rails test` before pushing code.
- For focused changes, run the relevant targeted tests first, then the full suite before pushing.
