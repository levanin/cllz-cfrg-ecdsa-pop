# Schnorr-Type Proofs of Possession for ECDSA Device Binding

This is the working area for the individual Internet-Draft, "Schnorr-Type
Proofs of Possession for ECDSA Device Binding".

* [Editor's Copy](https://levanin.github.io/cllz-cfrg-ecdsa-pop/#go.draft-cllz-cfrg-ecdsa-pop.html)
* [Datatracker Page](https://datatracker.ietf.org/doc/draft-cllz-cfrg-ecdsa-pop)
* [Individual Draft](https://datatracker.ietf.org/doc/html/draft-cllz-cfrg-ecdsa-pop)
* [Compare Editor's Copy to Individual Draft](https://author-tools.ietf.org/iddiff?url1=draft-cllz-cfrg-ecdsa-pop&url2=https://levanin.github.io/cllz-cfrg-ecdsa-pop/#go.draft-cllz-cfrg-ecdsa-pop.txt)


## Contributing

See the
[guidelines for contributions](https://github.com/levanin/cllz-cfrg-ecdsa-pop/blob/main/CONTRIBUTING.md).

Contributions can be made by creating pull requests.
The GitHub interface supports creating pull requests using the Edit (✏) button.


## Command Line Usage

Formatted text and HTML versions of the draft can be built using `make`.

```sh
make           # build build/draft.txt and build/draft.html
make txt       # only the text rendering
make html      # only the html rendering
make xml       # only the RFC XML
make clean     # remove generated documents (keeps build/refcache)
make distclean # remove the entire build/ directory
```

The draft is written in [kramdown-rfc] markdown
([draft-cllz-cfrg-ecdsa-pop.md](draft-cllz-cfrg-ecdsa-pop.md)); outputs are
written to `build/draft-cllz-cfrg-ecdsa-pop.{xml,txt,html}`. The first build
fetches referenced RFCs and Internet-Drafts over the network into
`build/refcache/`; later builds reuse that cache and work offline.

Command line usage requires that you have the necessary software installed.
Building needs two tools:

| Tool          | Purpose                       | Needs                  |
|---------------|-------------------------------|------------------------|
| `kramdown-rfc`| markdown → RFC XML (v3)        | Ruby >= 3.2            |
| `xml2rfc`     | RFC XML → text / html         | Python >= 3.8          |

### macOS

The system Ruby (2.6) is too old for current `kramdown-rfc`, so install a
modern Ruby via [Homebrew]:

```sh
brew install ruby                       # provides Ruby >= 3.2
gem install --user-install kramdown-rfc # or: sudo gem install kramdown-rfc
pip3 install --user xml2rfc
```

The Makefile already prepends the usual Homebrew Ruby and user-pip locations to
`PATH`, so `make` should work without further configuration. If your tools are
elsewhere, either put them on `PATH` or pass explicit paths:

```sh
make KRAMDOWN_RFC=/path/to/kramdown-rfc XML2RFC=/path/to/xml2rfc
```

### Linux

```sh
# Debian/Ubuntu
sudo apt-get install ruby python3-pip
# Fedora
# sudo dnf install ruby python3-pip

gem install --user-install kramdown-rfc
pip3 install --user xml2rfc
```

Ensure the user gem and pip bin directories are on your `PATH` (commonly
`~/.local/share/gem/ruby/*/bin` and `~/.local/bin`); add them to your shell
profile if `kramdown-rfc`/`xml2rfc` are not found.

[kramdown-rfc]: https://github.com/cabo/kramdown-rfc
[Homebrew]: https://brew.sh
