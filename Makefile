all: mod_status.la mod_secure_status.la

mod_status.la: mod_status.c mod_status.h
	apxs -c mod_status.c

mod_secure_status.la: mod_status.c mod_status.h
	apxs -c -o mod_secure_status.la mod_status.c

install: mod_secure_status.la
	apxs -i -n mod_secure_status mod_secure_status.la

clobber: mod_status.la
	apxs -i mod_status.la

clean:
	rm -rfv *~ *.o *.so *.lo *.la *.slo *.loT .libs/

patch:
	( \
		diff -u -p mod_status.c.orig mod_status.c > mod_secure_status.patch ; \
		exit 0 \
	)
	sed -ri 's#([+-]{3}) mod_status.c#\1 modules/generators/mod_status.c#' \
		mod_secure_status.patch
