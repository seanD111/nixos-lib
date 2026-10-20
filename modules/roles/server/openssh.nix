{
  services.openssh = {
    openFirewall = true;
    settings.PermitRootLogin = "prohibit-password";
  };
}
