(define-module (ebreak packages ch32-rs)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module (guix git-download)
  #:use-module (guix build-system cargo)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages pkg-config)
  #:use-module ((guix licenses) #:prefix license:)
  #:export (lookup-cargo-inputs))

;;; This file is auto-generated from Cargo.lock files.

(define qqqq-separator 'begin-of-crates)

(define rust-android-system-properties-0.1.5
  (crate-source "android_system_properties" "0.1.5"
                "04b3wrz12837j7mdczqd95b732gw5q7q66cv4yn4646lvccp57l1"))

(define rust-anstream-0.6.21
  (crate-source "anstream" "0.6.21"
                "0jjgixms4qjj58dzr846h2s29p8w7ynwr9b9x6246m1pwy0v5ma3"))

(define rust-anstyle-1.0.13
  (crate-source "anstyle" "1.0.13"
                "0y2ynjqajpny6q0amvfzzgw0gfw3l47z85km4gvx87vg02lcr4ji"))

(define rust-anstyle-parse-0.2.7
  (crate-source "anstyle-parse" "0.2.7"
                "1hhmkkfr95d462b3zf6yl2vfzdqfy5726ya572wwg8ha9y148xjf"))

(define rust-anstyle-query-1.1.5
  (crate-source "anstyle-query" "1.1.5"
                "1p6shfpnbghs6jsa0vnqd8bb8gd7pjd0jr7w0j8jikakzmr8zi20"))

(define rust-anstyle-wincon-3.0.11
  (crate-source "anstyle-wincon" "3.0.11"
                "0zblannm70sk3xny337mz7c6d8q8i24vhbqi42ld8v7q1wjnl7i9"))

(define rust-anyhow-1.0.100
  (crate-source "anyhow" "1.0.100"
                "0qbfmw4hhv2ampza1csyvf1jqjs2dgrj29cv3h3sh623c6qvcgm2"))

(define rust-autocfg-1.5.0
  (crate-source "autocfg" "1.5.0"
                "1s77f98id9l4af4alklmzq46f21c980v13z2r1pcxx6bqgw0d1n0"))

(define rust-bitfield-0.19.4
  (crate-source "bitfield" "0.19.4"
                "06b4qjc40kgyv0a5cxfx4a7l6f5hcjmqgqb0pq4bzwmhqqbnbfi1"))

(define rust-bitfield-macros-0.19.4
  (crate-source "bitfield-macros" "0.19.4"
                "15qym2fxzj079hic6xibci256h8812s6nmkbzm2ipprg4776m3gl"))

(define rust-bitflags-1.3.2
  (crate-source "bitflags" "1.3.2"
                "12ki6w8gn1ldq7yz9y680llwk5gmrhrzszaa17g1sbrw2r2qvwxy"))

(define rust-bitflags-2.10.0
  (crate-source "bitflags" "2.10.0"
                "1lqxwc3625lcjrjm5vygban9v8a6dlxisp1aqylibiaw52si4bl1"))

(define rust-bumpalo-3.19.0
  (crate-source "bumpalo" "3.19.0"
                "0hsdndvcpqbjb85ghrhska2qxvp9i75q2vb70hma9fxqawdy9ia6"))

(define rust-cc-1.2.48
  (crate-source "cc" "1.2.48"
                "0fk37741p34v904a49zcli9b65fmmir7sa06z3v95f6k1szvv0f4"))

(define rust-cc-1.2.49
  (crate-source "cc" "1.2.49"
                "05929ra8a2q81w45f932nr4blifnxkpr8i7lmcba28bm0c4k0n4h"))

(define rust-cfg-if-1.0.4
  (crate-source "cfg-if" "1.0.4"
                "008q28ajc546z5p2hcwdnckmg0hia7rnx52fni04bwqkzyrghc4k"))

(define rust-chrono-0.4.42
  (crate-source "chrono" "0.4.42"
                "1lp8iz9js9jwxw0sj8yi59v54lgvwdvm49b9wch77f25sfym4l0l"))

(define rust-clap-4.5.53
  (crate-source "clap" "4.5.53"
                "1y035lyy5w2xx83q4c3jiy75928ldm1x2bi8ylslkgx12bh41qy9"))

(define rust-clap-builder-4.5.53
  (crate-source "clap_builder" "4.5.53"
                "004xasw24a9vvzpiymjkm4khffpyzqwskz7ps8gr1351x89mssyp"))

(define rust-clap-derive-4.5.49
  (crate-source "clap_derive" "4.5.49"
                "0wbngw649138v3jwx8pm5x9sq0qsml3sh0sfzyrdxcpamy3m82ra"))

(define rust-clap-lex-0.7.6
  (crate-source "clap_lex" "0.7.6"
                "13cxw9m2rqvplgazgkq2awms0rgf34myc19bz6gywfngi762imx1"))

(define rust-clap-verbosity-flag-3.0.4
  (crate-source "clap-verbosity-flag" "3.0.4"
                "1513fiasgif7h7nxbnzs3ddkwm6n43lwcz5ph4w99zkjnbxb34lx"))

(define rust-colorchoice-1.0.4
  (crate-source "colorchoice" "1.0.4"
                "0x8ymkz1xr77rcj1cfanhf416pc4v681gmkc9dzb3jqja7f62nxh"))

(define rust-console-0.16.1
  (crate-source "console" "0.16.1"
                "1x4x6vfi1s55nbr4i77b9r87s213h46lq396sij9fkmidqx78c5l"))

(define rust-core-foundation-0.10.1
  (crate-source "core-foundation" "0.10.1"
                "1xjns6dqf36rni2x9f47b65grxwdm20kwdg9lhmzdrrkwadcv9mj"))

(define rust-core-foundation-sys-0.8.7
  (crate-source "core-foundation-sys" "0.8.7"
                "12w8j73lazxmr1z0h98hf3z623kl8ms7g07jch7n4p8f9nwlhdkp"))

(define rust-deranged-0.5.5
  (crate-source "deranged" "0.5.5"
                "11z5939gv2klp1r1lgrp4w5fnlkj18jqqf0h9zxmia3vkrjwpv7c"))

(define rust-encode-unicode-1.0.0
  (crate-source "encode_unicode" "1.0.0"
                "1h5j7j7byi289by63s3w4a8b3g6l5ccdrws7a67nn07vdxj77ail"))

(define rust-equivalent-1.0.2
  (crate-source "equivalent" "1.0.2"
                "03swzqznragy8n0x31lqc78g2af054jwivp7lkrbrc0khz74lyl7"))

(define rust-errno-0.3.14
  (crate-source "errno" "0.3.14"
                "1szgccmh8vgryqyadg8xd58mnwwicf39zmin3bsn63df2wbbgjir"))

(define rust-find-msvc-tools-0.1.5
  (crate-source "find-msvc-tools" "0.1.5"
                "0i1ql02y37bc7xywkqz10kx002vpz864vc4qq88h1jam190pcc1s"))

(define rust-futures-core-0.3.31
  (crate-source "futures-core" "0.3.31"
                "0gk6yrxgi5ihfanm2y431jadrll00n5ifhnpx090c2f2q1cr1wh5"))

(define rust-getrandom-0.3.4
  (crate-source "getrandom" "0.3.4"
                "1zbpvpicry9lrbjmkd4msgj3ihff1q92i334chk7pzf46xffz7c9"))

(define rust-hashbrown-0.16.1
  (crate-source "hashbrown" "0.16.1"
                "004i3njw38ji3bzdp9z178ba9x3k0c1pgy8x69pj7yfppv4iq7c4"))

(define rust-heck-0.5.0
  (crate-source "heck" "0.5.0"
                "1sjmpsdl8czyh9ywl3qcsfsq9a307dg4ni2vnlwgnzzqhc4y0113"))

(define rust-hex-0.4.3
  (crate-source "hex" "0.4.3"
                "0w1a4davm1lgzpamwnba907aysmlrnygbqmfis2mqjx5m552a93z"))

(define rust-hxdmp-0.2.1
  (crate-source "hxdmp" "0.2.1"
                "1c66j4z423w2lc3iqzzbg10y8ip58i90lpx7mimq8rklibr2fyx1"))

(define rust-iana-time-zone-0.1.64
  (crate-source "iana-time-zone" "0.1.64"
                "1yz980fmhaq9bdkasz35z63az37ci6kzzfhya83kgdqba61pzr9k"))

(define rust-iana-time-zone-haiku-0.1.2
  (crate-source "iana-time-zone-haiku" "0.1.2"
                "17r6jmj31chn7xs9698r122mapq85mfnv98bb4pg6spm0si2f67k"))

(define rust-ihex-3.0.0
  (crate-source "ihex" "3.0.0"
                "1wlzfyy5fsqgpki5vdapw0jjczqdm6813fgd3661wf5vfi3phnin"))

(define rust-indexmap-2.12.1
  (crate-source "indexmap" "2.12.1"
                "1wmcfk7g7d9wz1dninlijx70kfkzz6d5r36nyi2hdjjvaqmvpm0a"))

(define rust-indicatif-0.18.3
  (crate-source "indicatif" "0.18.3"
                "126b1nzklazk3mc5pazvch0s6rawai9ij0bc3hdyqqxlwh9f2xck"))

(define rust-io-kit-sys-0.4.1
  (crate-source "io-kit-sys" "0.4.1"
                "0ysy5k3wf54yangy25hkj10xx332cj2hb937xasg6riziv7yczk1"))

(define rust-is-terminal-polyfill-1.70.2
  (crate-source "is_terminal_polyfill" "1.70.2"
                "15anlc47sbz0jfs9q8fhwf0h3vs2w4imc030shdnq54sny5i7jx6"))

(define rust-itoa-1.0.15
  (crate-source "itoa" "1.0.15"
                "0b4fj9kz54dr3wam0vprjwgygvycyw8r0qwg7vp19ly8b2w16psa"))

(define rust-js-sys-0.3.83
  (crate-source "js-sys" "0.3.83"
                "1n71vpxrzclly0530lwkcsx6mg73lipam2ak3rr1ypzmqw4kfjj6"))

(define rust-libc-0.2.178
  (crate-source "libc" "0.2.178"
                "1490yks6mria93i3xdva1gm05cjz824g14mbv0ph32lxma6kvj9p"))

(define rust-libloading-0.9.0
  (crate-source "libloading" "0.9.0"
                "0q4bvhp4kqy2v3bw4cn2bmyq73hskqd1ansa9125gfq5x0ns4k3m"))

(define rust-libudev-0.3.0
  (crate-source "libudev" "0.3.0"
                "1q1my5alvdwyi8i9pc9gn2mcx5rhbsssmz5cjnxzfpd65laj9cvq"))

(define rust-libudev-sys-0.1.4
  (crate-source "libudev-sys" "0.1.4"
                "09236fdzlx9l0dlrsc6xx21v5x8flpfm3d5rjq9jr5ivlas6k11w"))

(define rust-libusb1-sys-0.7.0
  (crate-source "libusb1-sys" "0.7.0"
                "03yfx469d1ldpw2h21hy322f5a0h1ahlgy4s6yjipzy4gbg0l1fs"))

(define rust-linux-raw-sys-0.11.0
  (crate-source "linux-raw-sys" "0.11.0"
                "0fghx0nn8nvbz5yzgizfcwd6ap2pislp68j8c1bwyr6sacxkq7fz"))

(define rust-linux-raw-sys-0.9.4
  (crate-source "linux-raw-sys" "0.9.4"
                "04kyjdrq79lz9ibrf7czk6cv9d3jl597pb9738vzbsbzy1j5i56d"))

(define rust-log-0.4.29
  (crate-source "log" "0.4.29"
                "15q8j9c8g5zpkcw0hnd6cf2z7fxqnvsjh3rw5mv5q10r83i34l2y"))

(define rust-mach2-0.4.3
  (crate-source "mach2" "0.4.3"
                "0i6vcnbq5v51whgyidzhf7cbxqrmj2nkw8z0m2ib02rc60mjhh6n"))

(define rust-memchr-2.7.6
  (crate-source "memchr" "2.7.6"
                "0wy29kf6pb4fbhfksjbs05jy2f32r2f3r1ga6qkmpz31k79h0azm"))

(define rust-nix-0.26.4
  (crate-source "nix" "0.26.4"
                "06xgl4ybb8pvjrbmc3xggbgk3kbs1j0c4c0nzdfrmpbgrkrym2sr"))

(define rust-nu-ansi-term-0.50.3
  (crate-source "nu-ansi-term" "0.50.3"
                "1ra088d885lbd21q1bxgpqdlk1zlndblmarn948jz2a40xsbjmvr"))

(define rust-nu-pretty-hex-0.109.1
  (crate-source "nu-pretty-hex" "0.109.1"
                "1vwal7a75gly5q738wq8mm61ar9rmf2r8pfnp91w9i2ac131amh2"))

(define rust-num-conv-0.1.0
  (crate-source "num-conv" "0.1.0"
                "1ndiyg82q73783jq18isi71a7mjh56wxrk52rlvyx0mi5z9ibmai"))

(define rust-num-threads-0.1.7
  (crate-source "num_threads" "0.1.7"
                "1ngajbmhrgyhzrlc4d5ga9ych1vrfcvfsiqz6zv0h2dpr2wrhwsw"))

(define rust-num-traits-0.2.19
  (crate-source "num-traits" "0.2.19"
                "0h984rhdkkqd4ny9cif7y2azl3xdfb7768hb9irhpsch4q3gq787"))

(define rust-nusb-0.2.1
  (crate-source "nusb" "0.2.1"
                "0gvnd44q8fzcybxzr86p95j7z1r2fxv17xvwfhhghy7fnd6ny8nh"))

(define rust-object-0.38.0
  (crate-source "object" "0.38.0"
                "0c7q6sfwhzwq2h89mjqjqlhk5fg8adjrqkxww3c0r4j3plj8zcmq"))

(define rust-once-cell-1.21.3
  (crate-source "once_cell" "1.21.3"
                "0b9x77lb9f1j6nqgf5aka4s2qj0nly176bpbrv6f9iakk5ff3xa2"))

(define rust-once-cell-polyfill-1.70.2
  (crate-source "once_cell_polyfill" "1.70.2"
                "1zmla628f0sk3fhjdjqzgxhalr2xrfna958s632z65bjsfv8ljrq"))

(define rust-pkg-config-0.3.32
  (crate-source "pkg-config" "0.3.32"
                "0k4h3gnzs94sjb2ix6jyksacs52cf1fanpwsmlhjnwrdnp8dppby"))

(define rust-portable-atomic-1.11.1
  (crate-source "portable-atomic" "1.11.1"
                "10s4cx9y3jvw0idip09ar52s2kymq8rq9a668f793shn1ar6fhpq"))

(define rust-powerfmt-0.2.0
  (crate-source "powerfmt" "0.2.0"
                "14ckj2xdpkhv3h6l5sdmb9f1d57z8hbfpdldjc2vl5givq2y77j3"))

(define rust-ppv-lite86-0.2.21
  (crate-source "ppv-lite86" "0.2.21"
                "1abxx6qz5qnd43br1dd9b2savpihzjza8gb4fbzdql1gxp2f7sl5"))

(define rust-proc-macro2-1.0.103
  (crate-source "proc-macro2" "1.0.103"
                "1s29bz20xl2qk5ffs2mbdqknaj43ri673dz86axdbf47xz25psay"))

(define rust-quote-1.0.40
  (crate-source "quote" "1.0.40"
                "1394cxjg6nwld82pzp2d4fp6pmaz32gai1zh9z5hvh0dawww118q"))

(define rust-quote-1.0.42
  (crate-source "quote" "1.0.42"
                "0zq6yc7dhpap669m27rb4qfbiywxfah17z6fwvfccv3ys90wqf53"))

(define rust-r-efi-5.3.0
  (crate-source "r-efi" "5.3.0"
                "03sbfm3g7myvzyylff6qaxk4z6fy76yv860yy66jiswc2m6b7kb9"))

(define rust-rand-0.9.2
  (crate-source "rand" "0.9.2"
                "1lah73ainvrgl7brcxx0pwhpnqa3sm3qaj672034jz8i0q7pgckd"))

(define rust-rand-chacha-0.9.0
  (crate-source "rand_chacha" "0.9.0"
                "1jr5ygix7r60pz0s1cv3ms1f6pd1i9pcdmnxzzhjc3zn3mgjn0nk"))

(define rust-rand-core-0.9.3
  (crate-source "rand_core" "0.9.3"
                "0f3xhf16yks5ic6kmgxcpv1ngdhp48mmfy4ag82i1wnwh8ws3ncr"))

(define rust-rusb-0.9.4
  (crate-source "rusb" "0.9.4"
                "1905rijhabvylblh24379229hjmkfhxr80jc79aqd9v3bgq9z7xb"))

(define rust-rustix-1.1.2
  (crate-source "rustix" "1.1.2"
                "0gpz343xfzx16x82s1x336n0kr49j02cvhgxdvaq86jmqnigh5fd"))

(define rust-rustversion-1.0.22
  (crate-source "rustversion" "1.0.22"
                "0vfl70jhv72scd9rfqgr2n11m5i9l1acnk684m2w83w0zbqdx75k"))

(define rust-ryu-1.0.20
  (crate-source "ryu" "1.0.20"
                "07s855l8sb333h6bpn24pka5sp7hjk2w667xy6a0khkf6sqv5lr8"))

(define rust-scopeguard-1.2.0
  (crate-source "scopeguard" "1.2.0"
                "0jcz9sd47zlsgcnm1hdw0664krxwb5gczlif4qngj2aif8vky54l"))

(define rust-scroll-0.13.0
  (crate-source "scroll" "0.13.0"
                "1pbs3vxhrxcvj9hbjw4hiijbqlz0lkfxc9351mv34hcb4ka7q9f1"))

(define rust-serde-1.0.228
  (crate-source "serde" "1.0.228"
                "17mf4hhjxv5m90g42wmlbc61hdhlm6j9hwfkpcnd72rpgzm993ls"))

(define rust-serde-core-1.0.228
  (crate-source "serde_core" "1.0.228"
                "1bb7id2xwx8izq50098s5j2sqrrvk31jbbrjqygyan6ask3qbls1"))

(define rust-serde-derive-1.0.228
  (crate-source "serde_derive" "1.0.228"
                "0y8xm7fvmr2kjcd029g9fijpndh8csv5m20g4bd76w8qschg4h6m"))

(define rust-serde-yaml-0.9.34+deprecated
  (crate-source "serde_yaml" "0.9.34+deprecated"
                "0isba1fjyg3l6rxk156k600ilzr8fp7crv82rhal0rxz5qd1m2va"))

(define rust-serialport-4.7.3
  (crate-source "serialport" "4.7.3"
                "0yq0qm0wfmh2gp9gig3gd0m0n68fqqzza5f4x9y6sqg8fgwz7jia"))

(define rust-shlex-1.3.0
  (crate-source "shlex" "1.3.0"
                "0r1y6bv26c1scpxvhg2cabimrmwgbp4p3wy6syj9n0c4s3q2znhg"))

(define rust-simplelog-0.12.2
  (crate-source "simplelog" "0.12.2"
                "1h59cp84gwdmbxiljq6qmqq1x3lv9ikc1gb32f5ya7pgzbdpl98n"))

(define rust-slab-0.4.11
  (crate-source "slab" "0.4.11"
                "12bm4s88rblq02jjbi1dw31984w61y2ldn13ifk5gsqgy97f8aks"))

(define rust-strsim-0.11.1
  (crate-source "strsim" "0.11.1"
                "0kzvqlw8hxqb7y598w1s0hxlnmi84sg5vsipp3yg5na5d1rvba3x"))

(define rust-syn-2.0.111
  (crate-source "syn" "2.0.111"
                "11rf9l6435w525vhqmnngcnwsly7x4xx369fmaqvswdbjjicj31r"))

(define rust-termcolor-1.4.1
  (crate-source "termcolor" "1.4.1"
                "0mappjh3fj3p2nmrg4y7qv94rchwi9mzmgmfflr8p2awdj7lyy86"))

(define rust-thiserror-2.0.17
  (crate-source "thiserror" "2.0.17"
                "1j2gixhm2c3s6g96vd0b01v0i0qz1101vfmw0032mdqj1z58fdgn"))

(define rust-thiserror-impl-2.0.17
  (crate-source "thiserror-impl" "2.0.17"
                "04y92yjwg1a4piwk9nayzjfs07sps8c4vq9jnsfq9qvxrn75rw9z"))

(define rust-time-0.3.44
  (crate-source "time" "0.3.44"
                "179awlwb36zly3nmz5h9awai1h4pbf1d83g2pmvlw4v1pgixkrwi"))

(define rust-time-core-0.1.6
  (crate-source "time-core" "0.1.6"
                "0sqwhg7n47gbffyr0zhipqcnskxgcgzz1ix8wirqs2rg3my8x1j0"))

(define rust-time-macros-0.2.24
  (crate-source "time-macros" "0.2.24"
                "1wzb6hnl35856f58cx259q7ijc4c7yis0qsnydvw5n8jbw9b1krh"))

(define rust-unescaper-0.1.6
  (crate-source "unescaper" "0.1.6"
                "09hzbayg38dvc298zygrx7wvs228bz197winnjl34i3alpii47f0"))

(define rust-unicode-ident-1.0.22
  (crate-source "unicode-ident" "1.0.22"
                "1x8xrz17vqi6qmkkcqr8cyf0an76ig7390j9cnqnk47zyv2gf4lk"))

(define rust-unicode-width-0.2.2
  (crate-source "unicode-width" "0.2.2"
                "0m7jjzlcccw716dy9423xxh0clys8pfpllc5smvfxrzdf66h9b5l"))

(define rust-unit-prefix-0.5.2
  (crate-source "unit-prefix" "0.5.2"
                "18xr6yhdvlxrv51y6js9npa3qhkzc5b1z4skr5kfzn7kkd449rc1"))

(define rust-unsafe-libyaml-0.2.11
  (crate-source "unsafe-libyaml" "0.2.11"
                "0qdq69ffl3v5pzx9kzxbghzn0fzn266i1xn70y88maybz9csqfk7"))

(define rust-utf8parse-0.2.2
  (crate-source "utf8parse" "0.2.2"
                "088807qwjq46azicqwbhlmzwrbkz7l4hpw43sdkdyyk524vdxaq6"))

(define rust-vcpkg-0.2.15
  (crate-source "vcpkg" "0.2.15"
                "09i4nf5y8lig6xgj3f7fyrvzd3nlaw4znrihw8psidvv5yk4xkdc"))

(define rust-wasip2-1.0.1+wasi-0.2.4
  (crate-source "wasip2" "1.0.1+wasi-0.2.4"
                "1rsqmpspwy0zja82xx7kbkbg9fv34a4a2if3sbd76dy64a244qh5"))

(define rust-wasm-bindgen-0.2.106
  (crate-source "wasm-bindgen" "0.2.106"
                "1zc0pcyv0w1dhp8r7ybmmfjsf4g18q784h0k7mv2sjm67x1ryx8d"))

(define rust-wasm-bindgen-macro-0.2.106
  (crate-source "wasm-bindgen-macro" "0.2.106"
                "1czfwzhqrkzyyhd3g58mdwb2jjk4q2pl9m1fajyfvfpq70k0vjs8"))

(define rust-wasm-bindgen-macro-support-0.2.106
  (crate-source "wasm-bindgen-macro-support" "0.2.106"
                "0h6ddq6cc6jf9phsdh2a3x8lpjhmkya86ihfz3fdk4jzrpamkyyf"))

(define rust-wasm-bindgen-shared-0.2.106
  (crate-source "wasm-bindgen-shared" "0.2.106"
                "1d0dh3jn77qz67n5zh0s3rvzlbjv926p0blq5bvng2v4gq2kiifb"))

(define rust-web-time-1.1.0
  (crate-source "web-time" "1.1.0"
                "1fx05yqx83dhx628wb70fyy10yjfq1jpl20qfqhdkymi13rq0ras"))

(define rust-winapi-0.3.9
  (crate-source "winapi" "0.3.9"
                "06gl025x418lchw1wxj64ycr7gha83m44cjr5sarhynd9xkrm0sw"))

(define rust-winapi-i686-pc-windows-gnu-0.4.0
  (crate-source "winapi-i686-pc-windows-gnu" "0.4.0"
                "1dmpa6mvcvzz16zg6d5vrfy4bxgg541wxrcip7cnshi06v38ffxc"))

(define rust-winapi-util-0.1.11
  (crate-source "winapi-util" "0.1.11"
                "08hdl7mkll7pz8whg869h58c1r9y7in0w0pk8fm24qc77k0b39y2"))

(define rust-winapi-x86-64-pc-windows-gnu-0.4.0
  (crate-source "winapi-x86_64-pc-windows-gnu" "0.4.0"
                "0gqq64czqb64kskjryj8isp62m2sgvx25yyj3kpc2myh85w24bki"))

(define rust-windows-aarch64-gnullvm-0.53.1
  (crate-source "windows_aarch64_gnullvm" "0.53.1"
                "0lqvdm510mka9w26vmga7hbkmrw9glzc90l4gya5qbxlm1pl3n59"))

(define rust-windows-aarch64-msvc-0.53.1
  (crate-source "windows_aarch64_msvc" "0.53.1"
                "01jh2adlwx043rji888b22whx4bm8alrk3khjpik5xn20kl85mxr"))

(define rust-windows-core-0.62.2
  (crate-source "windows-core" "0.62.2"
                "1swxpv1a8qvn3bkxv8cn663238h2jccq35ff3nsj61jdsca3ms5q"))

(define rust-windows-i686-gnu-0.53.1
  (crate-source "windows_i686_gnu" "0.53.1"
                "18wkcm82ldyg4figcsidzwbg1pqd49jpm98crfz0j7nqd6h6s3ln"))

(define rust-windows-i686-gnullvm-0.53.1
  (crate-source "windows_i686_gnullvm" "0.53.1"
                "030qaxqc4salz6l4immfb6sykc6gmhyir9wzn2w8mxj8038mjwzs"))

(define rust-windows-i686-msvc-0.53.1
  (crate-source "windows_i686_msvc" "0.53.1"
                "1hi6scw3mn2pbdl30ji5i4y8vvspb9b66l98kkz350pig58wfyhy"))

(define rust-windows-implement-0.60.2
  (crate-source "windows-implement" "0.60.2"
                "1psxhmklzcf3wjs4b8qb42qb6znvc142cb5pa74rsyxm1822wgh5"))

(define rust-windows-interface-0.59.3
  (crate-source "windows-interface" "0.59.3"
                "0n73cwrn4247d0axrk7gjp08p34x1723483jxjxjdfkh4m56qc9z"))

(define rust-windows-link-0.2.1
  (crate-source "windows-link" "0.2.1"
                "1rag186yfr3xx7piv5rg8b6im2dwcf8zldiflvb22xbzwli5507h"))

(define rust-windows-result-0.4.1
  (crate-source "windows-result" "0.4.1"
                "1d9yhmrmmfqh56zlj751s5wfm9a2aa7az9rd7nn5027nxa4zm0bp"))

(define rust-windows-strings-0.5.1
  (crate-source "windows-strings" "0.5.1"
                "14bhng9jqv4fyl7lqjz3az7vzh8pw0w4am49fsqgcz67d67x0dvq"))

(define rust-windows-sys-0.60.2
  (crate-source "windows-sys" "0.60.2"
                "1jrbc615ihqnhjhxplr2kw7rasrskv9wj3lr80hgfd42sbj01xgj"))

(define rust-windows-sys-0.61.2
  (crate-source "windows-sys" "0.61.2"
                "1z7k3y9b6b5h52kid57lvmvm05362zv1v8w0gc7xyv5xphlp44xf"))

(define rust-windows-targets-0.53.5
  (crate-source "windows-targets" "0.53.5"
                "1wv9j2gv3l6wj3gkw5j1kr6ymb5q6dfc42yvydjhv3mqa7szjia9"))

(define rust-windows-x86-64-gnu-0.53.1
  (crate-source "windows_x86_64_gnu" "0.53.1"
                "16d4yiysmfdlsrghndr97y57gh3kljkwhfdbcs05m1jasz6l4f4w"))

(define rust-windows-x86-64-gnullvm-0.53.1
  (crate-source "windows_x86_64_gnullvm" "0.53.1"
                "1qbspgv4g3q0vygkg8rnql5c6z3caqv38japiynyivh75ng1gyhg"))

(define rust-windows-x86-64-msvc-0.53.1
  (crate-source "windows_x86_64_msvc" "0.53.1"
                "0l6npq76vlq4ksn4bwsncpr8508mk0gmznm6wnhjg95d19gzzfyn"))

(define rust-wit-bindgen-0.46.0
  (crate-source "wit-bindgen" "0.46.0"
                "0ngysw50gp2wrrfxbwgp6dhw1g6sckknsn3wm7l00vaf7n48aypi"))

(define rust-zerocopy-0.8.31
  (crate-source "zerocopy" "0.8.31"
                "1hwqn8f0zd8h1a7qz2hxym4iaqyzk8kdxgalllydn2i5p6cfqx7x"))

(define rust-zerocopy-derive-0.8.31
  (crate-source "zerocopy-derive" "0.8.31"
                "0sjw20qqxbax8z8k9ifcmwjjlljjddpm0nmvih9zap7lzl4x5a6q"))

;;; Cargo inputs.

(define-cargo-inputs lookup-cargo-inputs
  (wchisp =>
   (list
    rust-anstream-0.6.21
    rust-anstyle-1.0.13
    rust-anstyle-parse-0.2.7
    rust-anstyle-query-1.1.5
    rust-anstyle-wincon-3.0.11
    rust-anyhow-1.0.100
    rust-bitfield-0.19.4
    rust-bitfield-macros-0.19.4
    rust-bitflags-1.3.2
    rust-bitflags-2.10.0
    rust-bumpalo-3.19.0
    rust-cc-1.2.49
    rust-cfg-if-1.0.4
    rust-clap-4.5.53
    rust-clap-builder-4.5.53
    rust-clap-derive-4.5.49
    rust-clap-lex-0.7.6
    rust-colorchoice-1.0.4
    rust-console-0.16.1
    rust-core-foundation-0.10.1
    rust-core-foundation-sys-0.8.7
    rust-deranged-0.5.5
    rust-encode-unicode-1.0.0
    rust-equivalent-1.0.2
    rust-find-msvc-tools-0.1.5
    rust-getrandom-0.3.4
    rust-hashbrown-0.16.1
    rust-heck-0.5.0
    rust-hex-0.4.3
    rust-hxdmp-0.2.1
    rust-ihex-3.0.0
    rust-indexmap-2.12.1
    rust-indicatif-0.18.3
    rust-io-kit-sys-0.4.1
    rust-is-terminal-polyfill-1.70.2
    rust-itoa-1.0.15
    rust-js-sys-0.3.83
    rust-libc-0.2.178
    rust-libloading-0.9.0
    rust-libusb1-sys-0.7.0
    rust-log-0.4.29
    rust-mach2-0.4.3
    rust-memchr-2.7.6
    rust-nix-0.26.4
    rust-num-conv-0.1.0
    rust-num-threads-0.1.7
    rust-object-0.38.0
    rust-once-cell-1.21.3
    rust-once-cell-polyfill-1.70.2
    rust-pkg-config-0.3.32
    rust-portable-atomic-1.11.1
    rust-powerfmt-0.2.0
    rust-ppv-lite86-0.2.21
    rust-proc-macro2-1.0.103
    rust-quote-1.0.42
    rust-r-efi-5.3.0
    rust-rand-0.9.2
    rust-rand-chacha-0.9.0
    rust-rand-core-0.9.3
    rust-rusb-0.9.4
    rust-rustversion-1.0.22
    rust-ryu-1.0.20
    rust-scopeguard-1.2.0
    rust-scroll-0.13.0
    rust-serde-1.0.228
    rust-serde-core-1.0.228
    rust-serde-derive-1.0.228
    rust-serde-yaml-0.9.34+deprecated
    rust-serialport-4.7.3
    rust-shlex-1.3.0
    rust-simplelog-0.12.2
    rust-strsim-0.11.1
    rust-syn-2.0.111
    rust-termcolor-1.4.1
    rust-thiserror-2.0.17
    rust-thiserror-impl-2.0.17
    rust-time-0.3.44
    rust-time-core-0.1.6
    rust-time-macros-0.2.24
    rust-unescaper-0.1.6
    rust-unicode-ident-1.0.22
    rust-unicode-width-0.2.2
    rust-unit-prefix-0.5.2
    rust-unsafe-libyaml-0.2.11
    rust-utf8parse-0.2.2
    rust-vcpkg-0.2.15
    rust-wasip2-1.0.1+wasi-0.2.4
    rust-wasm-bindgen-0.2.106
    rust-wasm-bindgen-macro-0.2.106
    rust-wasm-bindgen-macro-support-0.2.106
    rust-wasm-bindgen-shared-0.2.106
    rust-web-time-1.1.0
    rust-winapi-0.3.9
    rust-winapi-i686-pc-windows-gnu-0.4.0
    rust-winapi-util-0.1.11
    rust-winapi-x86-64-pc-windows-gnu-0.4.0
    rust-windows-link-0.2.1
    rust-windows-sys-0.61.2
    rust-wit-bindgen-0.46.0
    rust-zerocopy-0.8.31
    rust-zerocopy-derive-0.8.31
   ))
  (wlink =>
   (list
    rust-android-system-properties-0.1.5
    rust-anstream-0.6.21
    rust-anstyle-1.0.13
    rust-anstyle-parse-0.2.7
    rust-anstyle-query-1.1.5
    rust-anstyle-wincon-3.0.11
    rust-anyhow-1.0.100
    rust-autocfg-1.5.0
    rust-bitfield-0.19.4
    rust-bitfield-macros-0.19.4
    rust-bitflags-1.3.2
    rust-bitflags-2.10.0
    rust-bumpalo-3.19.0
    rust-cc-1.2.48
    rust-cfg-if-1.0.4
    rust-chrono-0.4.42
    rust-clap-4.5.53
    rust-clap-builder-4.5.53
    rust-clap-derive-4.5.49
    rust-clap-lex-0.7.6
    rust-clap-verbosity-flag-3.0.4
    rust-colorchoice-1.0.4
    rust-console-0.16.1
    rust-core-foundation-0.10.1
    rust-core-foundation-sys-0.8.7
    rust-deranged-0.5.5
    rust-encode-unicode-1.0.0
    rust-errno-0.3.14
    rust-find-msvc-tools-0.1.5
    rust-futures-core-0.3.31
    rust-heck-0.5.0
    rust-hex-0.4.3
    rust-iana-time-zone-0.1.64
    rust-iana-time-zone-haiku-0.1.2
    rust-ihex-3.0.0
    rust-indicatif-0.18.3
    rust-io-kit-sys-0.4.1
    rust-is-terminal-polyfill-1.70.2
    rust-itoa-1.0.15
    rust-js-sys-0.3.83
    rust-libc-0.2.178
    rust-libloading-0.9.0
    rust-libudev-0.3.0
    rust-libudev-sys-0.1.4
    rust-linux-raw-sys-0.11.0
    rust-linux-raw-sys-0.9.4
    rust-log-0.4.29
    rust-mach2-0.4.3
    rust-memchr-2.7.6
    rust-nix-0.26.4
    rust-nu-ansi-term-0.50.3
    rust-nu-pretty-hex-0.109.1
    rust-num-conv-0.1.0
    rust-num-threads-0.1.7
    rust-num-traits-0.2.19
    rust-nusb-0.2.1
    rust-object-0.38.0
    rust-once-cell-1.21.3
    rust-once-cell-polyfill-1.70.2
    rust-pkg-config-0.3.32
    rust-portable-atomic-1.11.1
    rust-powerfmt-0.2.0
    rust-proc-macro2-1.0.103
    rust-quote-1.0.40
    rust-rustix-1.1.2
    rust-rustversion-1.0.22
    rust-scopeguard-1.2.0
    rust-serde-1.0.228
    rust-serde-core-1.0.228
    rust-serde-derive-1.0.228
    rust-serialport-4.7.3
    rust-shlex-1.3.0
    rust-simplelog-0.12.2
    rust-slab-0.4.11
    rust-strsim-0.11.1
    rust-syn-2.0.111
    rust-termcolor-1.4.1
    rust-thiserror-2.0.17
    rust-thiserror-impl-2.0.17
    rust-time-0.3.44
    rust-time-core-0.1.6
    rust-time-macros-0.2.24
    rust-unescaper-0.1.6
    rust-unicode-ident-1.0.22
    rust-unicode-width-0.2.2
    rust-unit-prefix-0.5.2
    rust-utf8parse-0.2.2
    rust-wasm-bindgen-0.2.106
    rust-wasm-bindgen-macro-0.2.106
    rust-wasm-bindgen-macro-support-0.2.106
    rust-wasm-bindgen-shared-0.2.106
    rust-web-time-1.1.0
    rust-winapi-0.3.9
    rust-winapi-i686-pc-windows-gnu-0.4.0
    rust-winapi-util-0.1.11
    rust-winapi-x86-64-pc-windows-gnu-0.4.0
    rust-windows-aarch64-gnullvm-0.53.1
    rust-windows-aarch64-msvc-0.53.1
    rust-windows-core-0.62.2
    rust-windows-i686-gnu-0.53.1
    rust-windows-i686-gnullvm-0.53.1
    rust-windows-i686-msvc-0.53.1
    rust-windows-implement-0.60.2
    rust-windows-interface-0.59.3
    rust-windows-link-0.2.1
    rust-windows-result-0.4.1
    rust-windows-strings-0.5.1
    rust-windows-sys-0.60.2
    rust-windows-sys-0.61.2
    rust-windows-targets-0.53.5
    rust-windows-x86-64-gnu-0.53.1
    rust-windows-x86-64-gnullvm-0.53.1
    rust-windows-x86-64-msvc-0.53.1
   ))
  (else => (list)))


(define-public wchisp
  (package
    (name "wchisp")
    (version "0.3.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ch32-rs/wchisp.git")
             (commit "cefd8707df345f1fbd7795e15367281f440bbf05")))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0z8q99x12lhvdgshacryy8agx62g66qvw1x349jvypc9jx99k083"))))
    (build-system cargo-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'install-udev-rules
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((rules (string-append (assoc-ref outputs "out")
                                          "/lib/udev/rules.d")))
                (mkdir-p rules)
                (with-output-to-file (string-append rules "/50-wchisp.rules")
                  (lambda _
                    (display
                     (string-append
                      "# wchisp\n"
                      "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"1a86\", "
                      "ATTRS{idProduct}==\"55e0\", MODE=\"0660\", "
                      "GROUP=\"dialout\"\n")))))
              #t)))))
    (inputs (cargo-inputs 'wchisp #:module '(ebreak packages ch32-rs)))
    (home-page "https://github.com/ch32-rs/wchisp.git")
    (synopsis "Command-line implementation of WCHISPTool")
    (description
     "This package provides a command-line implementation of WCHISPTool,
for flashing WCH CH32 MCUs over USB.")
    (license license:gpl2)))

(define-public wch-link
  (package
    (name "wch-link")
    (version "0.1.2")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/ch32-rs/wlink.git")
             (commit "249f2c100005827dce8c7d82ff46917e52cddad9")))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "12gjc1ca4450hkpz0fgvfdbim6lllqvpg414s4h8q6wj2i0l4gyn"))))
    (build-system cargo-build-system)
    (arguments
     (list
      #:tests? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'install-udev-rules
            (lambda* (#:key outputs #:allow-other-keys)
              (let ((rules (string-append (assoc-ref outputs "out")
                                          "/lib/udev/rules.d")))
                (mkdir-p rules)
                (with-output-to-file (string-append rules "/50-wch-link.rules")
                  (lambda _
                    (display
                     (string-append
                      "# wlink\n"
                      "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"1a86\", "
                      "ATTRS{idProduct}==\"8010\", MODE=\"0660\", "
                      "GROUP=\"dialout\"\n"
                      "SUBSYSTEM==\"usb\", ATTRS{idVendor}==\"1a86\", "
                      "ATTRS{idProduct}==\"8009\", MODE=\"0660\", "
                      "GROUP=\"dialout\"\n")))))
              #t)))))
    (inputs (cons* eudev (cargo-inputs 'wlink #:module '(ebreak packages ch32-rs))))
    (native-inputs (list pkg-config))
    (home-page "https://github.com/ch32-rs/wlink.git")
    (synopsis "WCH-Link flash tool for WCH RISC-V MCUs")
    (description
     "This package provides the WCH-Link flash tool for WCH RISC-V MCUs
such as CH32V, CH56X, CH57X, CH58X, CH59X, CH32L103, CH32X035, CH641,
and CH643.")
    (license (list license:expat license:asl2.0))))
