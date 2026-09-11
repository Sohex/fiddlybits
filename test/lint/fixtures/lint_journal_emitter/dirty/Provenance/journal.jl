module Journal

const JOURNAL_PATH = "journal.toml"

emit(e) = open(JOURNAL_PATH, "a")

end
