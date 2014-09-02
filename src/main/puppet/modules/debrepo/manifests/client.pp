class debrepo::client {
     
   File  <<| title == "/etc/apt/sources.list.d/ijp.list" |>> 
   
   
   exec { "apt-update":
       command => "/usr/bin/apt-get update",
   }
   
   Exec["apt-update"] -> Package <| |>

}
