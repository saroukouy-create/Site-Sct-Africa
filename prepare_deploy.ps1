# ============================================================
# SCT Africa - Préparation du package de déploiement
# Cible : public_html de sct-africa.site
# ============================================================

$workspaceRoot = $PSScriptRoot
$latestSourceRoot = Join-Path $workspaceRoot "downloaded_site_full_latest_cfe"
$sourceRoot = $latestSourceRoot
$siteBaseUrl = 'https://sct-africa.site'
$siteHostName = ([System.Uri]$siteBaseUrl).Host

if (-not (Test-Path $sourceRoot)) {
    throw "Source principale introuvable : $sourceRoot"
}

$fallbackMirrorHost = Join-Path $sourceRoot $siteHostName
$mirrorHosts = @(Get-ChildItem -Path $sourceRoot -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "index.html")
})
$siteSource = if (Test-Path (Join-Path $fallbackMirrorHost "index.html")) {
    $fallbackMirrorHost
} elseif ($mirrorHosts.Count -gt 0) {
    $mirrorHosts[0].FullName
} elseif (Test-Path $fallbackMirrorHost) {
    $fallbackMirrorHost
} else {
    throw "Aucun miroir de site exploitable trouvé dans $sourceRoot"
}
$deployDir  = Join-Path $workspaceRoot "deploy"
$publishedSiteDir = Join-Path $workspaceRoot "public_html"
$customHomeSource = Join-Path $workspaceRoot "index.html"
$defaultHomeSource = Join-Path $siteSource "index.html"
$customStyleSource = Join-Path $workspaceRoot "style.css"
$customScriptSource = Join-Path $workspaceRoot "script.js"
$customLogoSource = Join-Path $workspaceRoot "Images\logo-sct.png"
$customHomeImageSource = Join-Path $workspaceRoot "Images\index_html\home-img.jpg"
$routeFiles = @(
    'about',
    'contact',
    'devis',
    'engagements',
    'missions',
    'products-accessoires',
    'products-imprimantes',
    'products-scanners'
)
$problematicScannerImageName = '015WrFMNVYzppJWM2axCFc1-1..v1569478939.jpg'
$sanitizedScannerImageName = '015WrFMNVYzppJWM2axCFc1-1-v1569478939.jpg'
$problematicScannerImage = 'i.pcmag.com/imagery/reviews/015WrFMNVYzppJWM2axCFc1-1..v1569478939.jpg'
$sanitizedScannerImage = 'i.pcmag.com/imagery/reviews/015WrFMNVYzppJWM2axCFc1-1-v1569478939.jpg'
$pageDescriptions = @{
    '' = 'SCT Africa fournit des solutions d impression, scanners, accessoires et services Xerox pour les entreprises en Afrique.'
    'about' = 'Decouvrez SCT Africa, son expertise, sa vision et son accompagnement pour les solutions bureautiques et d impression professionnelles.'
    'contact' = 'Contactez SCT Africa pour vos besoins en imprimantes Xerox, scanners, accessoires et accompagnement technique.'
    'devis' = 'Demandez un devis SCT Africa pour vos solutions d impression, scanners, accessoires et equipements bureautiques.'
    'engagements' = 'Consultez les engagements de SCT Africa pour la qualite de service, le conseil et la performance de vos equipements.'
    'missions' = 'Explorez les missions et realites de SCT Africa autour des solutions d impression, du numerique et des equipements professionnels.'
    'products-accessoires' = 'Retrouvez les accessoires proposes par SCT Africa pour completer vos equipements d impression et de numerisation.'
    'products-imprimantes' = 'Decouvrez les machines Xerox et les imprimantes professionnelles proposees par SCT Africa.'
    'products-scanners' = 'Consultez la gamme de scanners professionnels proposee par SCT Africa pour la numerisation documentaire.'
}

$lockedRouteSources = @{}
foreach ($routeFile in $routeFiles) {
    $publishedRouteSource = Join-Path $publishedSiteDir "$routeFile\index.html"
    if (Test-Path $publishedRouteSource) {
        $lockedRouteSources[$routeFile] = $publishedRouteSource
    }
}

function Copy-DirectoryContent {
    param(
        [string]$SourceDir,
        [string]$TargetDir,
        [switch]$OnlyMissing
    )

    if (-not (Test-Path $SourceDir)) { return }

    Get-ChildItem -Path $SourceDir -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($SourceDir.Length).TrimStart('\\')
        $targetPath = Join-Path $TargetDir $relativePath
        $targetParent = Split-Path $targetPath -Parent

        $blockedByFile = $false
        $currentPath = $TargetDir
        $segments = $relativePath -split '\\'

        if ($segments.Length -gt 1) {
            for ($i = 0; $i -lt ($segments.Length - 1); $i++) {
                $segment = $segments[$i]
                if ([string]::IsNullOrWhiteSpace($segment)) {
                    continue
                }

                $currentPath = Join-Path $currentPath $segment
                if ((Test-Path $currentPath) -and -not (Get-Item $currentPath).PSIsContainer) {
                    $blockedByFile = $true
                    break
                }
            }
        }

        if ($blockedByFile) {
            return
        }

        if (-not (Test-Path $targetParent)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }

        if ($OnlyMissing -and (Test-Path $targetPath)) {
            return
        }

        Copy-Item $_.FullName $targetPath -Force
    }
}

function Add-SeoMetadata {
    param(
        [string]$Content,
        [string]$RouteKey
    )

    $description = if ($pageDescriptions.ContainsKey($RouteKey)) {
        $pageDescriptions[$RouteKey]
    } else {
        $pageDescriptions['']
    }

    $canonicalUrl = if ([string]::IsNullOrWhiteSpace($RouteKey)) {
        "$siteBaseUrl/"
    } else {
        "$siteBaseUrl/$RouteKey/"
    }

    if ($Content -match '<meta name="description"') {
        return $Content
    }

    $titleMatch = [regex]::Match($Content, '<title>(.*?)</title>', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    $pageTitle = if ($titleMatch.Success) {
        $titleMatch.Groups[1].Value.Trim()
    } else {
        'SCT AFRICA'
    }

    $escapedDescription = [System.Security.SecurityElement]::Escape($description)
    $escapedTitle = [System.Security.SecurityElement]::Escape($pageTitle)
    $seoBlock = @"
    <meta name="description" content="$escapedDescription" />
    <meta name="robots" content="index,follow" />
    <link rel="canonical" href="$canonicalUrl" />
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content="SCT AFRICA" />
    <meta property="og:title" content="$escapedTitle" />
    <meta property="og:description" content="$escapedDescription" />
    <meta property="og:url" content="$canonicalUrl" />
"@

    return $Content -replace '</title>', "</title>`r`n$seoBlock"
}

function Normalize-FinalHtmlPaths {
    param(
        [string]$Content
    )

    $Content = $Content.Replace('href="index.html"', 'href="/"')
    $Content = $Content.Replace('href="about"', 'href="/about/"')
    $Content = $Content.Replace('href="contact"', 'href="/contact/"')
    $Content = $Content.Replace('href="devis"', 'href="/devis/"')
    $Content = $Content.Replace('href="missions"', 'href="/missions/"')
    $Content = $Content.Replace('href="engagements"', 'href="/engagements/"')
    $Content = $Content.Replace('href="products-imprimantes"', 'href="/products-imprimantes/"')
    $Content = $Content.Replace('href="products-accessoires"', 'href="/products-accessoires/"')
    $Content = $Content.Replace('href="products-scanners"', 'href="/products-scanners/"')
    $Content = $Content.Replace('src="image/', 'src="/image/')
    $Content = $Content.Replace('href="image/', 'href="/image/')

    return $Content
}

function Apply-HtmlHarmonization {
    param(
        [string]$Content
    )

    $absoluteRouteMappings = [ordered]@{
        '' = '/'
        'about' = '/about/'
        'missions' = '/missions/'
        'engagements' = '/engagements/'
        'contact' = '/contact/'
        'devis' = '/devis/'
        'products-imprimantes' = '/products-imprimantes/'
        'products-accessoires' = '/products-accessoires/'
        'products-scanners' = '/products-scanners/'
    }

    foreach ($route in $absoluteRouteMappings.Keys) {
        $targetPath = $absoluteRouteMappings[$route]
        $escapedRoute = [regex]::Escape($route)
        $routePattern = if ([string]::IsNullOrEmpty($route)) { '/?' } else { "/$escapedRoute/?" }

        $Content = [regex]::Replace(
            $Content,
            "href=\"https?://[^\"/]+$routePattern\"",
            "href=\"$targetPath\"",
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
    }

    $Content = [regex]::Replace(
        $Content,
        'src="https?://[^"/]+/image/sct-afrik\.png"',
        'src="/image/sct-afrik.png"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $Content = [regex]::Replace(
        $Content,
        'src="https?://[^"/]+/image/home-img\.jpg"',
        'src="/image/home-img.jpg"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $Content = [regex]::Replace(
        $Content,
        'src="https?://[^"/]+/image/xerox-image\.webp"',
        'src="/image/xerox-image.webp"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $Content = [regex]::Replace(
        $Content,
        'src="https?://[^"/]+/image/img/imp-xerox\.jpg"',
        'src="/image/img/imp-xerox.jpg"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $Content = [regex]::Replace(
        $Content,
        'href="https?://[^"/]+/build/assets/app-n0BMUso-\.css"',
        'href="/build/assets/app-n0BMUso-.css"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $Content = [regex]::Replace(
        $Content,
        'href="https?://[^"/]+/build/assets/app-BGDHvcUF\.js"',
        'href="/build/assets/app-BGDHvcUF.js"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )
    $Content = [regex]::Replace(
        $Content,
        'src="https?://[^"/]+/build/assets/app-BGDHvcUF\.js"',
        'src="/build/assets/app-BGDHvcUF.js"',
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
    )

    $replacements = [ordered]@{
        'href="#contact"' = 'href="/contact/"'
        'href="https://sct-africa.site/assets/logo%20SCT.png"' = 'href="/assets/logo_20SCT.png"'
        'src="https://sct-africa.site/assets/logo%20SCT.png"' = 'src="/assets/logo_20SCT.png"'
        'src="https://sct-africa.site/assets/Logo%20Xerox.png"' = 'src="/assets/Logo_20Xerox.png"'
        'src="https://www.beart.fr/wp-content/uploads/2024/10/imprimante-laser-professionnelle.jpg"' = 'src="/www.beart.fr/wp-content/uploads/2024/10/imprimante-laser-professionnelle.jpg"'
        'src="https://www.xerox.com/assets/images/brand_engine/products/hardware/ALC82XX/short-hero_800x400.jpg"' = 'src="/www.xerox.com/assets/images/brand_engine/products/hardware/ALC82XX/short-hero_800x400.jpg"'
        'src="https://www.encreservices.fr/storage/products/xerox-115r00128-receptacle-de-poudre-toner-original.jpg"' = 'src="/www.encreservices.fr/storage/products/xerox-115r00128-receptacle-de-poudre-toner-original.jpg"'
        'src="https://m.media-amazon.com/images/I/71P6z6yPZpL._AC_SL1500_.jpg"' = 'src="/m.media-amazon.com/images/I/71P6z6yPZpL._AC_SL1500_.jpg"'
        'src="https://images.ctfassets.net/ao073xfdpkqn/5b2fTEESs6XCyo5xArsabH/1129dc324523a055ccdf451bf297b738/Print-Piece-Observing-2400x1600.jpg"' = 'src="/images.ctfassets.net/ao073xfdpkqn/5b2fTEESs6XCyo5xArsabH/1129dc324523a055ccdf451bf297b738/Print-Piece-Observing-2400x1600.jpg"'
        'src="https://upload.wikimedia.org/wikipedia/commons/thumb/6/68/Xerox_logo.svg/1200px-Xerox_logo.svg.png"' = 'src="/upload.wikimedia.org/wikipedia/commons/thumb/6/68/Xerox_logo.svg/1200px-Xerox_logo.svg.png"'
        '<script src="//unpkg.com/alpinejs" defer></script>' = '<script src="/unpkg.com/alpinejs" defer></script>'
        '<link rel="stylesheet" href="https://rsms.me/inter/inter.css" />' = '<link rel="stylesheet" href="/rsms.me/inter/inter.css" />'
        '<script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>' = '<script type="module" src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.esm.js"></script>'
        '<script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>' = '<script nomodule src="https://unpkg.com/ionicons@7.1.0/dist/ionicons/ionicons.js"></script>'
        '<link href="https://unpkg.com/aos@2.3.1/dist/aos.css" rel="stylesheet">' = '<link href="/unpkg.com/aos@2.3.1/dist/aos.css" rel="stylesheet">'
        '<script src="https://unpkg.com/aos@2.3.1/dist/aos.js"></script>' = '<script src="/unpkg.com/aos@2.3.1/dist/aos.js"></script>'
        '@import url(''https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap'');' = '@import url(''/fonts.googleapis.com/css2'');'
        '<a href="#" class="hover:text-accent transition">Accueil</a>' = '<a href="/" class="hover:text-accent transition">Accueil</a>'
        '<a href="#" class="hover:text-accent transition">Qui sommes-nous ?</a>' = '<a href="/about/" class="hover:text-accent transition">Qui sommes-nous ?</a>'
        '<a href="#" class="hover:text-accent transition">Nos produits</a>' = '<a href="/products-imprimantes/" class="hover:text-accent transition">Nos produits</a>'
        '<a href="#" class="hover:text-accent transition">Solutions</a>' = '<a href="/devis/" class="hover:text-accent transition">Solutions</a>'
        '<a href="#" class="hover:text-accent transition">Contact</a>' = '<a href="/contact/" class="hover:text-accent transition">Contact</a>'
        '<a href="#" class="hover:text-accent transition">Machines Xerox</a>' = '<a href="/products-imprimantes/" class="hover:text-accent transition">Machines Xerox</a>'
        '<a href="#" class="hover:text-accent transition">Solutions d''impression</a>' = '<a href="/devis/" class="hover:text-accent transition">Solutions d''impression</a>'
        '<a href="#" class="hover:text-accent transition">Accessoires</a>' = '<a href="/products-accessoires/" class="hover:text-accent transition">Accessoires</a>'
        '<a href="#" class="hover:text-accent transition">Scanners</a>' = '<a href="/products-scanners/" class="hover:text-accent transition">Scanners</a>'
        '<a href="#" class="hover:text-accent transition">Logiciels d''impression</a>' = '<a href="/contact/" class="hover:text-accent transition">Logiciels d''impression</a>'
        '<a href="#" class="inline-block bg-primary text-white px-4 py-2 rounded hover:bg-secondary transition">En savoir plus</a>' = '<a href="/contact/" class="inline-block bg-primary text-white px-4 py-2 rounded hover:bg-secondary transition">En savoir plus</a>'
    }

    foreach ($replacement in $replacements.GetEnumerator()) {
        $Content = $Content.Replace($replacement.Key, $replacement.Value)
    }

    $Content = $Content.Replace("https://images.unsplash.com/photo-1504384308090-c894fdcc538d?auto=format&fit=crop&w=1170&q=80", "/image/home-img.jpg")
    $Content = $Content.Replace("https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=1170&q=80", "/image/xerox-image.webp")
    $Content = $Content.Replace("https://images.unsplash.com/photo-1498050108023-c5249f4df085?auto=format&fit=crop&w=1170&q=80", "/image/img/imp-xerox.jpg")
    $Content = $Content.Replace("https://images.unsplash.com/photo-1522202176988-66273c2fd55f?auto=format&fit=crop&w=1170&q=80", "/www.beart.fr/wp-content/uploads/2024/10/imprimante-laser-professionnelle.jpg")

    $Content = $Content.Replace('href="deploy/', 'href="/')
    $Content = $Content.Replace('src="deploy/', 'src="/')
    $Content = $Content.Replace("image: 'deploy/", "image: '/")
    $Content = $Content.Replace("@import url('deploy/", "@import url('/")
    $Content = $Content.Replace('href="index.html"', 'href="/"')
    $Content = $Content.Replace('href="about"', 'href="/about/"')
    $Content = $Content.Replace('href="contact"', 'href="/contact/"')
    $Content = $Content.Replace('href="devis"', 'href="/devis/"')
    $Content = $Content.Replace('href="missions"', 'href="/missions/"')
    $Content = $Content.Replace('href="engagements"', 'href="/engagements/"')
    $Content = $Content.Replace('href="products-imprimantes"', 'href="/products-imprimantes/"')
    $Content = $Content.Replace('href="products-accessoires"', 'href="/products-accessoires/"')
    $Content = $Content.Replace('href="products-scanners"', 'href="/products-scanners/"')
    $Content = $Content.Replace('src="image/', 'src="/image/')
    $Content = $Content.Replace('href="image/', 'href="/image/')
    $Content = $Content.Replace('href="build/assets/', 'href="/build/assets/')
    $Content = $Content.Replace('src="build/assets/', 'src="/build/assets/')
    $Content = $Content.Replace('/sct-africa.site/assets/', '/assets/')
    $Content = $Content.Replace('../sct-africa.site/assets/', '/assets/')
    $Content = $Content.Replace('../../sct-africa.site/assets/', '/assets/')
    $Content = $Content.Replace($problematicScannerImageName, $sanitizedScannerImageName)
    $Content = $Content.Replace($problematicScannerImage, $sanitizedScannerImage)

    $Content = $Content.Replace('<a href="#" class="block px-4 py-2.5 hover:bg-gray-50 smooth-transition">`r`n                            <div class="flex items-center">`r`n                                <ion-icon name="hardware-chip-outline" class="text-gray-400 mr-3"></ion-icon>`r`n                                <span>Imprimante <span x-text="searchQuery" class="font-medium"></span></span>`r`n                            </div>`r`n                        </a>', '<a href="/products-imprimantes/" class="block px-4 py-2.5 hover:bg-gray-50 smooth-transition">`r`n                            <div class="flex items-center">`r`n                                <ion-icon name="hardware-chip-outline" class="text-gray-400 mr-3"></ion-icon>`r`n                                <span>Imprimante <span x-text="searchQuery" class="font-medium"></span></span>`r`n                            </div>`r`n                        </a>')
    $Content = $Content.Replace('<a href="#" class="block px-4 py-2.5 hover:bg-gray-50 smooth-transition">`r`n                            <div class="flex items-center">`r`n                                <ion-icon name="document-outline" class="text-gray-400 mr-3"></ion-icon>`r`n                                <span>Scanner <span x-text="searchQuery" class="font-medium"></span></span>`r`n                            </div>`r`n                        </a>', '<a href="/products-scanners/" class="block px-4 py-2.5 hover:bg-gray-50 smooth-transition">`r`n                            <div class="flex items-center">`r`n                                <ion-icon name="document-outline" class="text-gray-400 mr-3"></ion-icon>`r`n                                <span>Scanner <span x-text="searchQuery" class="font-medium"></span></span>`r`n                            </div>`r`n                        </a>')
    $Content = $Content.Replace('<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Solutions d''impression`r`n            </a>', '<a href="/devis/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Solutions d''impression`r`n            </a>')
    $Content = $Content.Replace('<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Logiciels d''impression`r`n            </a>', '<a href="/contact/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Logiciels d''impression`r`n            </a>')
    $Content = $Content.Replace('<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Tablettes`r`n            </a>', '<a href="/contact/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Tablettes`r`n            </a>')
    $Content = $Content.Replace('<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Logiciels`r`n            </a>', '<a href="/contact/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Logiciels`r`n            </a>')
    $Content = $Content.Replace('<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Cartouches`r`n            </a>', '<a href="/products-accessoires/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Cartouches`r`n            </a>')
    $Content = $Content.Replace('<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Papiers`r`n            </a>', '<a href="/products-accessoires/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">`r`n                Papiers`r`n            </a>')
    $Content = $Content.Replace('<li><a href="#" class="hover:text-secondary smooth-transition flex items-center">`r`n                                <ion-icon name="chevron-forward-outline" class="mr-2 text-xs text-gray-400"></ion-icon>`r`n                                Solutions d''impression`r`n                            </a></li>', '<li><a href="/devis/" class="hover:text-secondary smooth-transition flex items-center">`r`n                                <ion-icon name="chevron-forward-outline" class="mr-2 text-xs text-gray-400"></ion-icon>`r`n                                Solutions d''impression`r`n                            </a></li>')
    $Content = $Content.Replace('<li><a href="#" class="hover:text-secondary smooth-transition flex items-center">`r`n                                <ion-icon name="chevron-forward-outline" class="mr-2 text-xs text-gray-400"></ion-icon>`r`n                                Logiciels d''impression`r`n                            </a></li>', '<li><a href="/contact/" class="hover:text-secondary smooth-transition flex items-center">`r`n                                <ion-icon name="chevron-forward-outline" class="mr-2 text-xs text-gray-400"></ion-icon>`r`n                                Logiciels d''impression`r`n                            </a></li>')

    $Content = [regex]::Replace(
        $Content,
        '<a href="#"\s+class="inline-flex items-center space-x-2 bg-primary text-white px-6 py-3 rounded-xl hover:bg-secondary transition-all duration-300 group-hover:shadow-lg font-semibold">\s*<span>Découvrir</span>',
        '<a href="/contact/" class="inline-flex items-center space-x-2 bg-primary text-white px-6 py-3 rounded-xl hover:bg-secondary transition-all duration-300 group-hover:shadow-lg font-semibold"><span>Découvrir</span>'
    )

    $Content = [regex]::Replace(
        $Content,
        '<a href="#" class="block px-4 py-2\.5 hover:bg-gray-50 smooth-transition">\s*<div class="flex items-center">\s*<ion-icon name="hardware-chip-outline"',
        '<a href="/products-imprimantes/" class="block px-4 py-2.5 hover:bg-gray-50 smooth-transition"><div class="flex items-center"><ion-icon name="hardware-chip-outline"'
    )
    $Content = [regex]::Replace(
        $Content,
        '<a href="#" class="block px-4 py-2\.5 hover:bg-gray-50 smooth-transition">\s*<div class="flex items-center">\s*<ion-icon name="document-outline"',
        '<a href="/products-scanners/" class="block px-4 py-2.5 hover:bg-gray-50 smooth-transition"><div class="flex items-center"><ion-icon name="document-outline"'
    )
    $Content = [regex]::Replace(
        $Content,
        '<a href="#" class="hover:text-secondary smooth-transition flex items-center">\s*<ion-icon name="chevron-forward-outline" class="mr-2 text-xs text-gray-400"></ion-icon>\s*Solutions d''impression\s*</a>',
        '<a href="/devis/" class="hover:text-secondary smooth-transition flex items-center"><ion-icon name="chevron-forward-outline" class="mr-2 text-xs text-gray-400"></ion-icon>Solutions d''impression</a>'
    )
    $Content = [regex]::Replace(
        $Content,
        '<a href="#" class="hover:text-secondary smooth-transition flex items-center">\s*<ion-icon name="chevron-forward-outline" class="mr-2 text-xs text-gray-400"></ion-icon>\s*Logiciels d''impression\s*</a>',
        '<a href="/contact/" class="hover:text-secondary smooth-transition flex items-center"><ion-icon name="chevron-forward-outline" class="mr-2 text-xs text-gray-400"></ion-icon>Logiciels d''impression</a>'
    )
    $Content = [regex]::Replace($Content, '<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">\s*Solutions d''impression\s*</a>', '<a href="/devis/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">Solutions d''impression</a>')
    $Content = [regex]::Replace($Content, '<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">\s*Logiciels d''impression\s*</a>', '<a href="/contact/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">Logiciels d''impression</a>')
    $Content = [regex]::Replace($Content, '<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">\s*Tablettes\s*</a>', '<a href="/contact/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">Tablettes</a>')
    $Content = [regex]::Replace($Content, '<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">\s*Logiciels\s*</a>', '<a href="/contact/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">Logiciels</a>')
    $Content = [regex]::Replace($Content, '<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">\s*Cartouches\s*</a>', '<a href="/products-accessoires/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">Cartouches</a>')
    $Content = [regex]::Replace($Content, '<a href="#" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">\s*Papiers\s*</a>', '<a href="/products-accessoires/" class="block py-2 px-4 rounded-lg hover:bg-gray-50 smooth-transition">Papiers</a>')
    $Content = [regex]::Replace(
        $Content,
        '(<h3 class="text-xl font-semibold text-gray-900 mb-2">Solutions d''impression</h3>.*?<a href=")(" class="text-primary font-medium hover:underline">En savoir plus\.\.\.</a>)',
        '$1/devis/$2',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    $Content = [regex]::Replace(
        $Content,
        '(<h3 class="text-xl font-semibold text-gray-900 mb-2">Logiciels d''impression</h3>.*?<a href=")(" class="text-primary font-medium hover:underline">En savoir plus\.\.\.</a>)',
        '$1/contact/$2',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )

    return $Content
}

# --- 1. Nettoyage et création du dossier deploy ----------------
Write-Host "`n[1/5] Création du dossier deploy..." -ForegroundColor Cyan
if (Test-Path $deployDir) { Remove-Item $deployDir -Recurse -Force }
New-Item -ItemType Directory -Path $deployDir | Out-Null

# --- 2. Copie des fichiers du site ----------------------------
Write-Host "[2/5] Copie des fichiers du site (sct-africa.site)..." -ForegroundColor Cyan

# On copie tout SAUF le dossier 'https_' (artefact de téléchargement)
Get-ChildItem -Path $siteSource | Where-Object { $_.Name -notlike "'https_*" } | ForEach-Object {
    if ($_.PSIsContainer) {
        Copy-Item $_.FullName "$deployDir\$($_.Name)" -Recurse
    } else {
        Copy-Item $_.FullName "$deployDir\$($_.Name)"
    }
}

# Les logos utiles se trouvent sous le host sct-africa.site dans le miroir recent.
$fallbackAssetsDir = Join-Path $fallbackMirrorHost "assets"
if (Test-Path $fallbackAssetsDir) {
    Copy-DirectoryContent -SourceDir $fallbackAssetsDir -TargetDir (Join-Path $deployDir "assets") -OnlyMissing
}

Write-Host "   Site copié." -ForegroundColor Green

# --- 3. Copie des dossiers CDN (assets locaux) ----------------
Write-Host "[3/5] Copie des dossiers CDN/assets..." -ForegroundColor Cyan

$excludedTopLevelDirectories = @($siteHostName)

if ($mirrorHosts.Count -gt 0) {
    $excludedTopLevelDirectories += $mirrorHosts | Select-Object -ExpandProperty Name
    $excludedTopLevelDirectories = $excludedTopLevelDirectories | Sort-Object -Unique
}

$assetRoots = @($sourceRoot)
$assetDirectories = foreach ($assetRoot in $assetRoots) {
    if (Test-Path $assetRoot) {
        Get-ChildItem -Path $assetRoot -Directory |
            Where-Object { $_.Name -notin $excludedTopLevelDirectories } |
            Select-Object -ExpandProperty Name
    }
}

$assetDirectories = $assetDirectories | Sort-Object -Unique

foreach ($assetDirectory in $assetDirectories) {
    $primarySourceDir = Join-Path $sourceRoot $assetDirectory
    $targetDir = Join-Path $deployDir $assetDirectory

    if (Test-Path $primarySourceDir) {
        Copy-DirectoryContent -SourceDir $primarySourceDir -TargetDir $targetDir
    }

    Write-Host "   + $assetDirectory" -ForegroundColor Gray
}

$logoSource = Join-Path $deployDir "assets\logo%20SCT.png"
$logoAlias = Join-Path $deployDir "assets\logo_20SCT.png"
if ((Test-Path $logoSource) -and -not (Test-Path $logoAlias)) {
    Copy-Item $logoSource $logoAlias -Force
}

$xeroxLogoSource = Join-Path $deployDir "assets\Logo%20Xerox.png"
$xeroxLogoAlias = Join-Path $deployDir "assets\Logo_20Xerox.png"
if ((Test-Path $xeroxLogoSource) -and -not (Test-Path $xeroxLogoAlias)) {
    Copy-Item $xeroxLogoSource $xeroxLogoAlias -Force
}

$problematicScannerImagePath = Join-Path $deployDir ($problematicScannerImage.Replace('/', '\'))
$sanitizedScannerImagePath = Join-Path $deployDir ($sanitizedScannerImage.Replace('/', '\'))
if (Test-Path $problematicScannerImagePath) {
    $sanitizedScannerImageParent = Split-Path $sanitizedScannerImagePath -Parent
    if (-not (Test-Path $sanitizedScannerImageParent)) {
        New-Item -ItemType Directory -Path $sanitizedScannerImageParent -Force | Out-Null
    }

    Move-Item -Path $problematicScannerImagePath -Destination $sanitizedScannerImagePath -Force
}

# --- 4. Synchronisation de l'accueil personnalisé -------------
Write-Host "[4/5] Synchronisation de l'accueil personnalisé..." -ForegroundColor Cyan

if (Test-Path $customLogoSource) {
    New-Item -ItemType Directory -Path (Join-Path $deployDir "image") -Force | Out-Null
    Copy-Item $customLogoSource (Join-Path $deployDir "image\logo-sct.png") -Force
    Write-Host "   Logo SCT synchronisé." -ForegroundColor Green
}

if (Test-Path $customHomeImageSource) {
    New-Item -ItemType Directory -Path (Join-Path $deployDir "image") -Force | Out-Null
    Copy-Item $customHomeImageSource (Join-Path $deployDir "image\home-img.jpg") -Force
    Write-Host "   Image d'accueil synchronisée." -ForegroundColor Green
}

if (Test-Path $customStyleSource) {
    Copy-Item $customStyleSource (Join-Path $deployDir "style.css") -Force
    Write-Host "   Feuille de style locale synchronisée." -ForegroundColor Green
}

if (Test-Path $customScriptSource) {
    Copy-Item $customScriptSource (Join-Path $deployDir "script.js") -Force
    Write-Host "   Script local synchronisé." -ForegroundColor Green
}

if (Test-Path $customHomeSource) {
    Copy-Item $customHomeSource (Join-Path $deployDir 'index.html') -Force
    Write-Host "   Accueil personnalisé verrouillé et copié tel quel." -ForegroundColor Green
} elseif (Test-Path $defaultHomeSource) {
    $customHome = [System.IO.File]::ReadAllText($defaultHomeSource, [System.Text.Encoding]::UTF8)
    $customHome = $customHome.Replace('href="Images/logo-sct.png"', 'href="image/logo-sct.png"')
    $customHome = $customHome.Replace('src="Images/logo-sct.png"', 'src="image/logo-sct.png"')
    $customHome = $customHome.Replace('src="Images/index_html/home-img.jpg"', 'src="image/home-img.jpg"')
    $customHome = [regex]::Replace($customHome, 'downloaded_site_full_latest_cfe/[^/]+/build/assets/', 'build/assets/', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $customHome = $customHome.Replace('downloaded_site_full_latest_cfe/sct-africa.site/', '')
    $customHome = $customHome.Replace('downloaded_site_full_latest_cfe/', '')
    $customHome = Apply-HtmlHarmonization -Content $customHome
    $customHome = Add-SeoMetadata -Content $customHome -RouteKey ''
    $customHome = Normalize-FinalHtmlPaths -Content $customHome

    [System.IO.File]::WriteAllText((Join-Path $deployDir "index.html"), $customHome, [System.Text.Encoding]::UTF8)
    Write-Host "   Accueil miroir appliqué à deploy/index.html." -ForegroundColor Green
}

# --- 5. Correction des chemins dans les HTML ------------------
Write-Host "[5/5] Correction des chemins relatifs dans les fichiers HTML..." -ForegroundColor Cyan

# Regex : remplace (../)+ suivi d'un nom de domaine (contient un point) par /domaine/
# Ne touche PAS aux chemins internes comme ../image/, ../build/, ../assets/
$cdnPathRegex = [regex]'(\.\./)+([a-z0-9][a-z0-9\-]+\.[a-z]{2,}[a-z0-9\-\.]*\/)'

$htmlFiles = Get-ChildItem -Path $deployDir -Recurse -File | Where-Object {
    $_.Extension -eq '.html' -or
    ($_.DirectoryName -eq $deployDir -and [string]::IsNullOrEmpty($_.Extension))
} | Where-Object {
    $_.FullName -ne (Join-Path $deployDir 'index.html')
}
$fixedCount = 0

foreach ($file in $htmlFiles) {
    $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
    $newContent = $cdnPathRegex.Replace($content, '/$2')
    $newContent = Apply-HtmlHarmonization -Content $newContent

    $routeKey = ''
    if ($file.DirectoryName -eq $deployDir -and [string]::IsNullOrEmpty($file.Extension) -and ($routeFiles -contains $file.Name)) {
        $routeKey = $file.Name
    }

    $newContent = Add-SeoMetadata -Content $newContent -RouteKey $routeKey

    if ($newContent -ne $content) {
        [System.IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.Encoding]::UTF8)
        $fixedCount++
        Write-Host "   Corrigé : $($file.FullName.Replace($deployDir, ''))" -ForegroundColor Green
    }
}

Write-Host "   $fixedCount fichier(s) HTML corrigé(s)." -ForegroundColor Green

foreach ($routeFile in $routeFiles) {
    $flatRoutePath = Join-Path $deployDir $routeFile
    if (-not (Test-Path $flatRoutePath)) {
        continue
    }

    $routeDirectory = Join-Path $deployDir $routeFile
    $routeIndexPath = Join-Path $routeDirectory 'index.html'
    $routeContent = [System.IO.File]::ReadAllText($flatRoutePath, [System.Text.Encoding]::UTF8)

    Remove-Item $flatRoutePath -Force
    New-Item -ItemType Directory -Path $routeDirectory -Force | Out-Null
    [System.IO.File]::WriteAllText($routeIndexPath, $routeContent, [System.Text.Encoding]::UTF8)
}

foreach ($lockedRoute in $lockedRouteSources.Keys) {
    $lockedTargetDir = Join-Path $deployDir $lockedRoute
    $lockedTargetPath = Join-Path $lockedTargetDir 'index.html'

    if (-not (Test-Path $lockedTargetDir)) {
        New-Item -ItemType Directory -Path $lockedTargetDir -Force | Out-Null
    }

    Copy-Item $lockedRouteSources[$lockedRoute] $lockedTargetPath -Force
    Write-Host "   Page verrouillée restaurée : /$lockedRoute/" -ForegroundColor Green
}

$finalHtmlFiles = Get-ChildItem -Path $deployDir -Recurse -Filter '*.html' -File
foreach ($finalHtmlFile in $finalHtmlFiles) {
    if ($finalHtmlFile.FullName -eq (Join-Path $deployDir 'index.html')) {
        continue
    }

    $skipLockedRoute = $false
    foreach ($lockedRoute in $lockedRouteSources.Keys) {
        if ($finalHtmlFile.FullName -eq (Join-Path $deployDir "$lockedRoute\index.html")) {
            $skipLockedRoute = $true
            break
        }
    }

    if ($skipLockedRoute) {
        continue
    }

    $finalContent = [System.IO.File]::ReadAllText($finalHtmlFile.FullName, [System.Text.Encoding]::UTF8)
    $normalizedContent = Normalize-FinalHtmlPaths -Content $finalContent

    if ($normalizedContent -ne $finalContent) {
        [System.IO.File]::WriteAllText($finalHtmlFile.FullName, $normalizedContent, [System.Text.Encoding]::UTF8)
    }
}

# --- Création des fichiers SEO publics ------------------------
$sitemapUrls = @(
    "$siteBaseUrl/"
)

foreach ($routeFile in $routeFiles) {
    $sitemapUrls += "$siteBaseUrl/$routeFile/"
}

$lastMod = (Get-Date).ToString('yyyy-MM-dd')
$sitemapEntries = foreach ($url in $sitemapUrls) {
    "  <url><loc>$url</loc><lastmod>$lastMod</lastmod></url>"
}

$sitemapContent = @(
    '<?xml version="1.0" encoding="UTF-8"?>'
    '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
    $sitemapEntries
    '</urlset>'
) -join "`r`n"

[System.IO.File]::WriteAllText((Join-Path $deployDir 'sitemap.xml'), $sitemapContent, [System.Text.Encoding]::UTF8)

$robotsContent = @(
    'User-agent: *'
    'Allow: /'
    ''
    "Sitemap: $siteBaseUrl/sitemap.xml"
) -join "`r`n"

[System.IO.File]::WriteAllText((Join-Path $deployDir 'robots.txt'), $robotsContent, [System.Text.Encoding]::ASCII)
Write-Host "   robots.txt et sitemap.xml créés." -ForegroundColor Green

# --- Création du .htaccess ------------------------------------
$htaccess = @'
# SCT Africa - Configuration Apache
Options -Indexes

# Cache navigateur pour les assets statiques
<IfModule mod_expires.c>
    ExpiresActive On
    ExpiresByType text/css              "access plus 1 month"
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType image/png             "access plus 6 months"
    ExpiresByType image/jpeg            "access plus 6 months"
    ExpiresByType image/webp            "access plus 6 months"
    ExpiresByType image/svg+xml         "access plus 6 months"
    ExpiresByType font/woff2            "access plus 1 year"
</IfModule>

# Compression Gzip
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/css application/javascript
</IfModule>

# Redirection HTTPS
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{HTTP_HOST} ^(www\.)?sct-africa\.com$ [NC]
    RewriteRule ^ https://sct-africa.site%{REQUEST_URI} [L,R=301,NE]
    RewriteCond %{HTTPS} off
    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</IfModule>

# Pages propres sans .html
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME}.html -f
    RewriteRule ^(.*)$ $1.html [L]
</IfModule>
'@

$htaccessPath = "$deployDir\.htaccess"
[System.IO.File]::WriteAllText($htaccessPath, $htaccess, [System.Text.Encoding]::UTF8)
Write-Host "   .htaccess créé." -ForegroundColor Green

# --- Résumé ---------------------------------------------------
$totalFiles = (Get-ChildItem -Path $deployDir -Recurse -File).Count
Write-Host "`n====================================================" -ForegroundColor Yellow
Write-Host " Package de déploiement prêt !" -ForegroundColor Yellow
Write-Host " Dossier : $deployDir" -ForegroundColor Yellow
Write-Host " Total fichiers : $totalFiles" -ForegroundColor Yellow
Write-Host "====================================================" -ForegroundColor Yellow
Write-Host "`nProchaine étape : exécute Publier-Site-Final.cmd pour publier vers sct-africa.site" -ForegroundColor Cyan
