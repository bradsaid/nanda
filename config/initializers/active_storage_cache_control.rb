# Active Storage's proxy controllers already answer with
#   Cache-Control: max-age=3155760000, public
# (http_cache_forever). The URLs we serve through them (SurvivorsHelper#avatar_src,
# ShareImageHelper) are keyed by the blob + variation digest, so their bytes never change:
# add `immutable` so browsers do not even revalidate on reload. Redirect-mode URLs are not
# touched.
Rails.application.config.to_prepare do
  [ ActiveStorage::Representations::ProxyController, ActiveStorage::Blobs::ProxyController ].each do |controller|
    next if controller._process_action_callbacks.any? { |cb| cb.filter == :mark_proxy_response_immutable }

    controller.class_eval do
      after_action :mark_proxy_response_immutable

      private

      def mark_proxy_response_immutable
        return unless response.successful? && response.cache_control[:public]

        response.cache_control[:extras] = (Array(response.cache_control[:extras]) + [ "immutable" ]).uniq
      end
    end
  end
end
