use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::X;

describe 'hyphenated attribute keys', {
  it 'parses a hyphenated string key with rocket', {
    expect(HAML.render(:src(Q[%a{'data-id' => 1}] ~ "\n")))
      .to.eq("<a data-id='1'></a>\n");
  }

  it 'parses a hyphenated double-quoted string key', {
    expect(HAML.render(:src(Q[%a{"aria-label" => "x"}] ~ "\n")))
      .to.eq("<a aria-label='x'></a>\n");
  }

  it 'raises X::HAML::ParseFail on a bareword hyphen-key', {
    expect({ HAML.render(:src(Q[%a{data-id: 1}] ~ "\n")) })
      .to.raise-error(X::HAML::ParseFail);
  }
}
