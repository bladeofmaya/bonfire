# Base class for Bonfire-owned ViewComponents.
#
# Keep domain lookup and authorization out of this layer. Components receive
# already-authorized records and explicit presentation state from their caller.
class ApplicationComponent < ViewComponent::Base
end
