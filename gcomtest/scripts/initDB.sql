use gcom;
update users set info ='gcomappstest@gmail.com';
update users set id_photo='photos/nopict.jpg';
update users set password = '1a1dc91c907325c69271ddf0c944bc72';
update users set phone ='+212661592224';




update e_general_data set email='gcomappstest@gmail.com';
ALTER TABLE supplier DROP KEY email;	
update supplier set email='gcomappstest@gmail.com';
update customer set email='gcomappstest@gmail.com'; 
update e_general_data set id_photo='photos/nopict.jpg';

update supplier set password = '1a1dc91c907325c69271ddf0c944bc72';


update e_general_data set p_mobile ='+212661592224';
update external_resource set phone ='+212661592224';
update external_resource set email='gcomappstest@gmail.com';
update external_resource set password = '1a1dc91c907325c69271ddf0c944bc72';
update customer set photo = "nopict.jpg";

update  part_number set image = "resources/img/noimage.jpg";

update supplier set photo='photos/nopict.jpg';
update customer set photo='photos/nopict.jpg';

update supplier_category set photo='photos/nopict.jpg';
update customer_category set photo='photos/nopict.jpg';


update company set logo='photos/nopict.jpg';
update bankaccount set logo='photos/nopict.jpg' where logo is not null;


update part_number set image='photos/nopict.jpg';
update part_number_brand set image='photos/nopict.jpg';
update packing_detail_type set image='photos/nopict.jpg';

	
update company set logo='photos/nopict.jpg';

