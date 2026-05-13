
use Template::HAML::Helpers;

unit role Template::HAML::HelpersRole is export;

method html-safe(|c)         { &html-safe(|c)         }
method haml-concat(|c)       { &haml-concat(|c)       }
method escape-once(|c)       { &escape-once(|c)       }
method surround(|c)          { &surround(|c)          }
method precede(|c)           { &precede(|c)           }
method succeed(|c)           { &succeed(|c)           }
method list-of(|c)           { &list-of(|c)           }
method find-and-preserve(|c) { &find-and-preserve(|c) }
method capture-haml(|c)      { &capture-haml(|c)      }
method yield(|c)             { &Template::HAML::Helpers::yield(|c) }
method content-for(|c)       { &content-for(|c)       }
method tab-up(|c)            { &tab-up(|c)            }
method tab-down(|c)          { &tab-down(|c)          }
method partial(|c)           { &Template::HAML::Helpers::render(|c) }
