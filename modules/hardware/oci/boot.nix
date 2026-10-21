{
  boot = {
    kernelModules = [ ];
    extraModulePackages = [ ];
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
    };
    initrd = {
      systemd.enable = true;
      availableKernelModules = [
        "xhci_pci"
        "virtio_pci"
        "virtio_scsi"
        "usbhid"
      ];
      kernelModules = [ ];
    };
  };
}
