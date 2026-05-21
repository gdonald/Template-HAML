use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'hyphenated attribute keys', {
  it 'parses a hyphenated string key with rocket', {
    expect(HAML.render(:src(Q[%a{'data-id' => 1}] ~ "\n")))
      .to.eq("<a data-id='1'></a>\n");
  }

  it 'parses a hyphenated double-quoted string key', {
    expect(HAML.render(:src(Q[%a{"aria-label" => "x"}] ~ "\n")))
      .to.eq("<a aria-label='x'></a>\n");
  }

  it 'does not parse a bareword hyphen-key as an attribute', {
    my $r = HAML.render(:src(Q[%a{data-id: 1}] ~ "\n"));
    expect($r.contains("data-id='1'")).to.be-falsy;
  }
}
