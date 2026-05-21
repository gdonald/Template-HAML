use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Config;

describe 'hyphenate-data-attrs config', {
  it 'preserves camelCase data: keys by default', {
    my $r = HAML.render(:src(Q<%a{data: {fooBar: 1}}> ~ "\n"));
    expect($r).to.include("data-fooBar='1'");
  }

  it 'converts camelCase to kebab-case when enabled', {
    my $cfg = Template::HAML::Config.new(:hyphenate-data-attrs);
    my $r = HAML.render(:src(Q<%a{data: {fooBar: 1}}> ~ "\n"), :config($cfg));
    expect($r).to.eq("<a data-foo-bar='1'></a>\n");
  }

  it 'converts multiple humps in a single key', {
    my $cfg = Template::HAML::Config.new(:hyphenate-data-attrs);
    my $r = HAML.render(:src(Q<%a{data: {fooBarBaz: 1}}> ~ "\n"), :config($cfg));
    expect($r).to.eq("<a data-foo-bar-baz='1'></a>\n");
  }

  it 'hyphenates aria: keys too', {
    my $cfg = Template::HAML::Config.new(:hyphenate-data-attrs);
    my $r = HAML.render(:src(Q<%a{aria: {labelledBy: 'x'}}> ~ "\n"), :config($cfg));
    expect($r).to.eq("<a aria-labelled-by='x'></a>\n");
  }

  it 'hyphenates nested hash keys', {
    my $cfg = Template::HAML::Config.new(:hyphenate-data-attrs);
    my $r = HAML.render(:src(Q<%a{data: {userId: {fullName: 'x'}}}> ~ "\n"), :config($cfg));
    expect($r).to.eq("<a data-user-id-full-name='x'></a>\n");
  }

  it 'leaves plain lowercase data: keys unchanged', {
    my $cfg = Template::HAML::Config.new(:hyphenate-data-attrs);
    my $r = HAML.render(:src(Q<%a{data: {id: 1, role: 'foo'}}> ~ "\n"), :config($cfg));
    expect($r).to.include("data-id='1'");
    expect($r).to.include("data-role='foo'");
  }
}
