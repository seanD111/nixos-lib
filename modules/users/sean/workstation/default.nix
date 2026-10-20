{
  imports = [
    ./..
  ];

  users.users.sean = {
    extraGroups = [
      "video"
      "audio"
      "input"
      "scanner"
      "lp"
    ];
  };
}
