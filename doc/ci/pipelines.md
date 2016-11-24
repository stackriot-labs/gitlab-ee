# Introduction to pipelines and builds

>**Note:**
Introduced in GitLab 8.8.

## Pipelines

A pipeline is a group of [builds][] that get executed in [stages][](batches).
All of the builds in a stage are executed in parallel (if there are enough
concurrent [Runners]), and if they all succeed, the pipeline moves on to the
next stage. If one of the builds fails, the next stage is not (usually)
executed.

## Builds

Builds are individual runs of [jobs]. Not to be confused with a `build` job or
`build` stage.

## Defining pipelines

Pipelines are defined in `.gitlab-ci.yml` by specifying [jobs] that run in
[stages].

See full [documentation](yaml/README.md#jobs).

## Seeing pipeline status

You can find the current and historical pipeline runs under **Pipelines** for
your project.

## Seeing build status

Clicking on a pipeline will show the builds that were run for that pipeline.
Clicking on an individual build will show you its build trace, and allow you to
cancel the build, retry it,  or erase the build trace.

## Badges

Build status and test coverage report badges are available. You can find their
respective link in the [Pipelines settings] page.

[builds]: #builds
[jobs]: yaml/README.md#jobs
[stages]: yaml/README.md#stages
[runners]: runners/READM
[pipelines settings]: ../user/project/pipelines/settings.md
