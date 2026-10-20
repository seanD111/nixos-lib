{
  imports = [
    ./..
  ];

  users.users.sean = {
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZUum1O2MwTkQDrAtMlTttFlCteY26l2h6h0s+a7/Wg"
    ];
    isNormalUser = true;
    extraGroups = [
      "wheel"
    ];
  };
}
