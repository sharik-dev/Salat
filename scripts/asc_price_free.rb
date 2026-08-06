# Pose la tarification « gratuit » sur la fiche App Store.
#
#   ruby scripts/asc_price_free.rb
#
# Pourquoi un script et pas une lane : `deliver` ne sait plus poser un prix. Son
# option `price_tier` parle à l'ancienne API iTunes Connect, que les paliers
# (« tier 1 », « tier 2 »…) ont quittée en 2023 pour des *price points* par
# territoire. Sans prix, la soumission est refusée sur « App is not eligible for
# submission until pricing has been set » — une erreur qui ne dit pas où
# chercher, puisque tout le reste de la fiche part bien par fastlane.
#
# C'est un réglage **une fois par app**, pas par version : à lancer après
# `fastlane ios bootstrap`, jamais dans la chaîne de release.
#
# Le JWT ES256 est fabriqué avec OpenSSL de la stdlib — aucune gem à installer.
# `sign` rend une signature DER ; l'API en attend la forme brute r||s sur
# 64 octets, d'où la conversion par ASN1.

require "openssl"
require "base64"
require "json"
require "net/http"

BASE = "https://api.appstoreconnect.apple.com/v1"

def b64(s) = Base64.urlsafe_encode64(s).delete("=")

def token
  key = OpenSSL::PKey::EC.new(File.read(ENV.fetch("ASC_KEY_P8_PATH")))
  header  = b64({ alg: "ES256", kid: ENV.fetch("ASC_KEY_ID"), typ: "JWT" }.to_json)
  payload = b64({ iss: ENV.fetch("ASC_ISSUER_ID"),
                  exp: Time.now.to_i + 900,
                  aud: "appstoreconnect-v1" }.to_json)
  der  = key.sign(OpenSSL::Digest.new("SHA256"), "#{header}.#{payload}")
  r, s = OpenSSL::ASN1.decode(der).value.map { |v| v.value.to_s(2).rjust(32, "\x00") }
  "#{header}.#{payload}.#{b64(r + s)}"
end

TOK = token

def call(method, path, body = nil)
  uri = URI("#{BASE}/#{path}")
  req = (method == :get ? Net::HTTP::Get : Net::HTTP::Post).new(uri)
  req["Authorization"] = "Bearer #{TOK}"
  if body
    req["Content-Type"] = "application/json"
    req.body = body.to_json
  end
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  ok = method == :get ? [200] : [200, 201]
  abort("HTTP #{res.code} sur #{path}\n#{res.body}") unless ok.include?(res.code.to_i)
  res.body.empty? ? {} : JSON.parse(res.body)
end

# Le bundle se lit dans `project.yml` et nulle part ailleurs : c'est XcodeGen
# qui grave `PRODUCT_BUNDLE_IDENTIFIER` dans l'app, donc c'est ce fichier qui
# fait foi. Le recopier ici en donnerait une deuxième version, et c'est ce
# doublon qui fait qu'on livre un jour la fiche d'une app à une autre.
def app_bundle_id
  yml = File.read(File.expand_path("../project.yml", __dir__))
  # La cible `Salat` est la première du fichier ; le widget vient ensuite avec
  # son propre identifiant, qu'on ne veut surtout pas attraper.
  yml[/PRODUCT_BUNDLE_IDENTIFIER:\s*(\S+)/, 1] or
    abort("PRODUCT_BUNDLE_IDENTIFIER absent de project.yml")
end

bundle = app_bundle_id

apps = call(:get, "apps?filter[bundleId]=#{bundle}")
abort("Aucune fiche App Store pour #{bundle}") if apps["data"].empty?
app = apps["data"].first
puts "app : #{app['attributes']['name']} (#{app['id']})"

# Le prix se choisit par *price point*, et un price point appartient à un
# territoire. Les États-Unis servent de territoire de base — c'est celui dont
# Apple déduit les autres, et le seul qui existe à coup sûr sur toute fiche.
points = call(:get, "apps/#{app['id']}/appPricePoints?filter[territory]=USA&include=territory&limit=200")
# Comparer en nombre, jamais en chaîne : l'API rend « 0.0 » ici et « 0.00 »
# ailleurs, et une égalité de chaînes échoue alors sans rien dire d'utile.
free = points["data"].find { |p| p.dig("attributes", "customerPrice").to_f.zero? }
abort("Aucun price point gratuit trouvé pour les États-Unis.") unless free
puts "price point gratuit : #{free['id']}"

# `startDate: null` veut dire « maintenant, et sans fin ». Une date future
# laisserait la fiche sans prix d'ici là, donc toujours refusée à la soumission.
call(:post, "appPriceSchedules", {
  data: {
    type: "appPriceSchedules",
    relationships: {
      app: { data: { type: "apps", id: app["id"] } },
      baseTerritory: { data: { type: "territories", id: "USA" } },
      manualPrices: { data: [{ type: "appPrices", id: "${price1}" }] }
    }
  },
  included: [{
    id: "${price1}",
    type: "appPrices",
    attributes: { startDate: nil },
    relationships: { appPricePoint: { data: { type: "appPricePoints", id: free["id"] } } }
  }]
})

puts "✓ tarification posée : gratuit, tous territoires"
