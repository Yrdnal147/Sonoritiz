from rest_framework.views import exception_handler
from rest_framework.response import Response
from rest_framework import status
import logging

logger = logging.getLogger(__name__)

CODE_MAP = {
    400: "BAD_REQUEST",
    401: "UNAUTHORIZED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    429: "TOO_MANY_REQUESTS",
    500: "INTERNAL_SERVER_ERROR",
}

def custom_exception_handler(exc, context):
    """
    Standardized DRF Exception Handler.
    Formats all API errors to:
    {
        "error": {
            "code": "ERROR_CODE",
            "message": "Human readable summary error message."
        }
    }
    """
    response = exception_handler(exc, context)

    if response is not None:
        http_code = response.status_code
        error_code = CODE_MAP.get(http_code, "API_ERROR")

        # Extract message cleanly
        detail = response.data
        if isinstance(detail, dict):
            if "detail" in detail:
                msg = str(detail["detail"])
            elif "non_field_errors" in detail:
                msg = " ".join([str(e) for e in detail["non_field_errors"]])
            else:
                # Combine field error messages cleanly
                messages = []
                for field, errs in detail.items():
                    if isinstance(errs, list):
                        messages.append(f"{field}: {' '.join([str(e) for e in errs])}")
                    else:
                        messages.append(f"{field}: {errs}")
                msg = "; ".join(messages)
        elif isinstance(detail, list):
            msg = " ".join([str(e) for e in detail])
        else:
            msg = str(detail)

        response.data = {
            "error": {
                "code": error_code,
                "message": msg
            }
        }
        return response

    # Handle unhandled 500 exceptions cleanly without leaking stack traces in API response
    logger.error(f"Unhandled exception in API context: {exc}", exc_info=True)
    return Response(
        {
            "error": {
                "code": "INTERNAL_SERVER_ERROR",
                "message": "Une erreur interne s'est produite. Veuillez réessayer ultérieurement."
            }
        },
        status=status.HTTP_500_INTERNAL_SERVER_ERROR
    )
