use lib 'lib';
use BDD::Behave;
use Template::HAML;
use Template::HAML::Helpers;
use Template::HAML::HelpersRole;
use Template::HAML::ViewContext;

class UsersShowCtx does Template::HAML::HelpersRole {
  method controller-name { 'users' }
  method action-name     { 'show'  }
}

class CtrlOnly does Template::HAML::HelpersRole {
  method controller-name { 'posts' }
}

class ActionOnly does Template::HAML::HelpersRole {
  method action-name { 'index' }
}

class LegacyCtx does Template::HAML::HelpersRole {
  method controller { 'Admin::Users' }
  method action     { 'New Post'     }
}

class EmptyCtx does Template::HAML::HelpersRole {
  method controller-name { '' }
  method action-name     { '' }
}

describe 'page-class', {
  context 'sub form', {
    it 'joins with default separator', {
      expect(page-class(:controller<users>, :action<show>)).to.be('users-show');
    }

    it 'uses provided separator', {
      expect(page-class(:controller<users>, :action<show>, :separator<_>))
        .to.be('users_show');
    }

    it 'prefix prepended with separator', {
      expect(page-class(:controller<users>, :action<show>, :prefix<page>))
        .to.be('page-users-show');
    }

    it 'lone controller', {
      expect(page-class(:controller<users>)).to.be('users');
    }

    it 'lone action', {
      expect(page-class(:action<show>)).to.be('show');
    }

    it 'empty when nothing to derive', {
      expect(page-class()).to.be('');
    }

    it 'slugifies non-word chars', {
      expect(page-class(:controller('Admin::Users'), :action('New Post')))
        .to.be('admin-users-new-post');
    }
  }

  context 'template integration', {
    it 'derives from user context via shorthand-interp', {
      my $src = q:to/HAML/;
      %body.#{page-class()}
        %p hi
      HAML
      my $out = HAML.render(:$src, :context(UsersShowCtx.new));
      expect($out).to.match(/'<body class=' <[\"\']> 'users-show' <[\"\']> '>'/);
    }

    it 'bare ident resolution via = output', {
      my $src = q:to/HAML/;
      %span
        = page-class
      HAML
      my $out = HAML.render(:$src, :context(UsersShowCtx.new));
      expect($out).to.match(/'users-show'/);
    }

    it 'only controller available', {
      my $src = q:to/HAML/;
      %body.#{page-class()}
      HAML
      my $out = HAML.render(:$src, :context(CtrlOnly.new));
      expect($out).to.match(/'<body class=' <[\"\']> 'posts' <[\"\']> '>'/);
    }

    it 'only action available', {
      my $src = q:to/HAML/;
      %body.#{page-class()}
      HAML
      my $out = HAML.render(:$src, :context(ActionOnly.new));
      expect($out).to.match(/'<body class=' <[\"\']> 'index' <[\"\']> '>'/);
    }

    it 'legacy controller/action method names', {
      my $src = q:to/HAML/;
      %body.#{page-class()}
      HAML
      my $out = HAML.render(:$src, :context(LegacyCtx.new));
      expect($out).to.match(/'<body class=' <[\"\']> 'admin-users-new-post' <[\"\']> '>'/);
    }

    it 'empty context values produce empty string', {
      my $src = q:to/HAML/;
      %span
        = page-class()
      HAML
      my $out = HAML.render(:$src, :context(EmptyCtx.new));
      expect($out).to.match(/'<span>' \s* '</span>'/);
    }

    it 'explicit kwargs override context', {
      my $src = q:to/HAML/;
      %body.#{page-class(:controller<admin>, :action<dash>)}
      HAML
      my $out = HAML.render(:$src, :context(UsersShowCtx.new));
      expect($out).to.match(/'<body class=' <[\"\']> 'admin-dash' <[\"\']> '>'/);
    }

    it 'default context returns empty', {
      my $src = q:to/HAML/;
      %p
        = page-class()
      HAML
      my $out = HAML.render(:$src);
      expect($out).to.match(/'<p>' \s* '</p>'/);
    }
  }

  context 'HelpersRole', {
    it 'exposes page-class on ViewContext', {
      my $vc = Template::HAML::ViewContext.new;
      expect($vc.^can('page-class')).to.be-truthy;
    }
  }

  context 'method form', {
    it 'reads controller-name/action-name from self', {
      my $vc = UsersShowCtx.new;
      expect($vc.page-class).to.be('users-show');
    }

    it 'accepts kwargs override', {
      my $vc = UsersShowCtx.new;
      expect($vc.page-class(:controller<a>, :action<b>)).to.be('a-b');
    }
  }
}
