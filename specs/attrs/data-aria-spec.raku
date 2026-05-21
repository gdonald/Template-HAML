use lib 'lib';
use BDD::Behave;
use Template::HAML;

describe 'data: / aria: hash expansion', {
  it 'expands a data: hash to data-* attributes', {
    my $r = HAML.render(:src(Q<%a{data: {id: 1, role: 'foo'}}> ~ "\n"));
    expect($r).to.include("data-id='1'");
    expect($r).to.include("data-role='foo'");
  }

  it 'expands an aria: hash and renders True as a bare attribute', {
    my $r = HAML.render(:src(Q<%a{aria: {label: 'x', hidden: True}}> ~ "\n"));
    expect($r).to.include("aria-label='x'");
    expect($r).to.include("aria-hidden");
  }

  it 'recursively expands data:user:id', {
    my $r = HAML.render(:src(Q<%a{data: {user: {id: 1}}}> ~ "\n"));
    expect($r).to.eq("<a data-user-id='1'></a>\n");
  }

  it 'recurses to deeper nested levels', {
    my $r = HAML.render(:src(Q<%a{data: {user: {profile: {url: '/u'}}}}> ~ "\n"));
    expect($r).to.eq("<a data-user-profile-url='/u'></a>\n");
  }

  it 'mixes leaf and nested data: entries', {
    my $r = HAML.render(:src(Q<%a{data: {x: 1, y: {z: 2}}}> ~ "\n"));
    expect($r).to.include("data-x='1'");
    expect($r).to.include("data-y-z='2'");
  }
}
