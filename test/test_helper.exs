Application.ensure_all_started(:postgrex)
Lifebelt.Test.Repo.start_link()
ExUnit.start()
