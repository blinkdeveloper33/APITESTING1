{ pkgs, ... }: {
  channel = "stable-24.05";
  
  packages = [
    pkgs.jdk17
    pkgs.unzip
  ];
  
  env = {};
  services.docker.enable = true;
  
  idx = {
    extensions = [
      "Dart-Code.flutter"
      "Dart-Code.dart-code"
    ];
    
    workspace = {
      onCreate = {
        build-flutter = ''
          cd /home/user/myapp/android

          ./gradlew \
            --parallel \
            -Pverbose=true \
            -Ptarget-platform=android-x86 \
            -Ptarget=/home/user/myapp/lib/main.dart \
            -Pbase-application-name=android.app.Application \
            -Pdart-obfuscation=false \
            -Ptrack-widget-creation=true \
            -Ptree-shake-icons=false \
            -Pfilesystem-scheme=org-dartlang-root \
            assembleDebug
        '';
      };
    };
    
    previews = {
      enable = true;
      previews = {
        android = {
          command = ["flutter" "run" "--machine" "-d" "android" "-d" "localhost:5555"];
          manager = "flutter";
        };
      };
    };
  };
}