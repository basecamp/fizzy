class QrCodesController < ApplicationController
  allow_unauthenticated_access

  def show
    expires_in 1.year, public: true

    qr_code_svg = RQRCode::QRCode
      .new(QrCodeLink.from_signed(params[:id]).url)
      .as_svg(viewbox: true, fill: :white, color: :black, offset: 16)

    render svg: qr_code_svg
  end
end
